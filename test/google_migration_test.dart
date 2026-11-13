import 'dart:convert';
import 'dart:io';

import 'package:authenticator/entities/account_code.dart';
import 'package:authenticator/import/google_migration.dart';
import 'package:authenticator/home/google_import.screen.dart';
import 'package:authenticator/repository.dart' as storage;
import 'package:authenticator/storage/account_store.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'provisioning_test.dart' show FakeScanner;

List<int> varint(int value) {
  final out = <int>[];
  do {
    final byte = value & 127;
    value >>= 7;
    out.add(value == 0 ? byte : byte | 128);
  } while (value != 0);
  return out;
}

List<int> integer(int field, int value) => [
  ...varint(field << 3),
  ...varint(value),
];
List<int> bytes(int field, List<int> value) => [
  ...varint(field << 3 | 2),
  ...varint(value.length),
  ...value,
];
List<int> account({
  String label = 'Acme:alice',
  int algorithm = 1,
  int digits = 1,
  int type = 2,
  int counter = 0,
}) => [
  ...bytes(1, ascii.encode('12345678901234567890')),
  ...bytes(2, utf8.encode(label)),
  ...bytes(3, utf8.encode('Acme')),
  ...integer(4, algorithm),
  ...integer(5, digits),
  ...integer(6, type),
  if (type == 1) ...integer(7, counter),
];
String qr(
  List<List<int>> accounts, {
  int version = 1,
  int size = 1,
  int index = 0,
  int id = 123,
}) {
  final payload = [
    for (final a in accounts) ...bytes(1, a),
    ...integer(2, version),
    ...integer(3, size),
    ...integer(4, index),
    ...integer(5, id),
  ];
  return 'otpauth-migration://offline?data=${Uri.encodeQueryComponent(base64.encode(payload))}';
}

String qrBytes(List<int> payload) =>
    'otpauth-migration://offline?data=${Uri.encodeQueryComponent(base64.encode(payload))}';

void main() {
  test('single QR parses a standard TOTP account', () {
    final fragment = parseGoogleMigration(qr([account()]));
    expect(fragment.batchSize, 1);
    expect(fragment.batchIndex, 0);
    expect(fragment.accounts.single.issuer, 'Acme');
    expect(fragment.accounts.single.name, 'alice');
    expect(
      accountCode(
        fragment.accounts.single,
        at: DateTime.fromMillisecondsSinceEpoch(59000, isUtc: true),
      ),
      '287082',
    );
  });
  test(
    'collects out of order and detects repeats, conflicts and other batches',
    () {
      final batch = MigrationBatch();
      final first = parseGoogleMigration(qr([account()], size: 2, index: 0));
      final second = parseGoogleMigration(
        qr([account(label: 'Acme:bob')], size: 2, index: 1),
      );
      expect(batch.add(second), isTrue);
      expect(batch.complete, isFalse);
      expect(batch.add(second), isFalse);
      expect(
        () => batch.add(
          parseGoogleMigration(
            qr([account(label: 'Acme:eve')], size: 2, index: 1),
          ),
        ),
        throwsFormatException,
      );
      expect(
        () =>
            batch.add(parseGoogleMigration(qr([account()], size: 2, id: 124))),
        throwsFormatException,
      );
      expect(batch.add(first), isTrue);
      expect(batch.complete, isTrue);
      expect(batch.accounts.map((x) => x.name).toList(), ['alice', 'bob']);
      batch.clear();
      expect(batch.received, 0);
      expect(batch.complete, isFalse);
    },
  );
  test('preserves HOTP counter and nondefault parameters', () {
    final a = parseGoogleMigration(
      qr([account(type: 1, counter: 1, algorithm: 2, digits: 2)]),
    ).accounts.single;
    expect(a.counter, 1);
    expect(a.algorithm.name, 'sha256');
    expect(a.digits, 8);
  });
  test('accepts omitted proto3 zero-valued index, id and HOTP counter', () {
    final hotp = [
      ...bytes(1, ascii.encode('12345678901234567890')),
      ...bytes(2, utf8.encode('Acme:alice')),
      ...bytes(3, utf8.encode('Acme')),
      ...integer(4, 1),
      ...integer(5, 1),
      ...integer(6, 1),
    ];
    final fragment = parseGoogleMigration(
      qrBytes([...bytes(1, hotp), ...integer(2, 1), ...integer(3, 1)]),
    );
    expect(fragment.batchId, 0);
    expect(fragment.batchIndex, 0);
    expect(fragment.accounts.single.counter, 0);
    expect(accountCode(fragment.accounts.single), '755224');
  });
  test(
    'rejects truncated protobuf and invalid UTF-8 without leaking content',
    () {
      expect(
        () => parseGoogleMigration(qrBytes([0x0a, 0x7f, 0x01])),
        throwsFormatException,
      );
      final malformed = [
        ...bytes(1, [
          ...bytes(1, ascii.encode('12345678901234567890')),
          ...bytes(2, [0xff]),
          ...integer(4, 1),
          ...integer(5, 1),
          ...integer(6, 2),
        ]),
        ...integer(2, 1),
        ...integer(3, 1),
        ...integer(4, 0),
        ...integer(5, 123),
      ];
      expect(
        () => parseGoogleMigration(qrBytes(malformed)),
        throwsFormatException,
      );
    },
  );
  testWidgets('duplicate labels require choosing one and import atomically', (
    tester,
  ) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('google-import-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${directory.path}/accounts.sqlite3',
          legacyDirectory: directory.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    final fragment = parseGoogleMigration(
      qr([account(), account(algorithm: 2)]),
    );
    await tester.pumpWidget(CupertinoApp(home: GoogleImportScreen(fragment)));
    expect(find.text('Import 0 accounts'), findsOneWidget);
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pump();
    expect(find.text('Another matching account is selected.'), findsOneWidget);
    await tester.tap(find.text('Import 1 accounts'));
    await tester.pumpAndSettle();
    expect(repo.length, 1);
    expect(repo.values.single.name, 'alice');
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
  testWidgets('scans a complete two-QR batch before import', (tester) async {
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('google-batch-'),
    ))!;
    final repo = (await tester.runAsync(
      () async => storage.AccountRepository(
        await AccountStore.open(
          sqlitePath: '${directory.path}/accounts.sqlite3',
          legacyDirectory: directory.path,
          legacyLoader: () async => {},
        ),
      ),
    ))!;
    storage.accounts = repo;
    final oldPlatform = MobileScannerPlatform.instance;
    MobileScannerPlatform.instance = FakeScanner();
    final first = parseGoogleMigration(qr([account()], size: 2, index: 0));
    await tester.pumpWidget(CupertinoApp(home: GoogleImportScreen(first)));
    expect(find.text('Scanned 1 of 2 QR codes.'), findsOneWidget);
    expect(repo.length, 0);
    await tester.tap(find.text('Scan next QR code'));
    await tester.pumpAndSettle();
    tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
      BarcodeCapture(
        barcodes: [
          Barcode(
            format: BarcodeFormat.qrCode,
            rawValue: qr([account(label: 'Acme:bob')], size: 2, index: 1),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Import 2 accounts'), findsOneWidget);
    await tester.tap(find.text('Import 2 accounts'));
    await tester.pumpAndSettle();
    expect(repo.length, 2);
    await tester.pumpWidget(const SizedBox());
    MobileScannerPlatform.instance = oldPlatform;
    repo.dispose();
    final reopened = (await tester.runAsync(
      () => AccountStore.open(
        sqlitePath: '${directory.path}/accounts.sqlite3',
        legacyDirectory: directory.path,
        legacyLoader: () async => {},
      ),
    ))!;
    expect(reopened.length, 2);
    expect(reopened.values.map((a) => a.name).toSet(), {'alice', 'bob'});
    reopened.close();
    await tester.runAsync(() => directory.delete(recursive: true));
  });
  for (final invalid in [
    qr([account()], version: 2),
    qr([account()], size: 0),
    qr([account()], size: 2, index: 2),
    qr([account(algorithm: 4)]),
    qr([account(digits: 0)]),
    qr([account(type: 0)]),
    'otpauth-migration://offline?data=abc%ZZ',
    'otpauth-migration://offline?data=%%%',
  ]) {
    test(
      'rejects unsupported or malformed migration input ${invalid.hashCode}',
      () {
        expect(() => parseGoogleMigration(invalid), throwsFormatException);
      },
    );
  }
}
