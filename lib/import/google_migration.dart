import 'dart:convert';
import 'dart:typed_data';

import 'package:base32/base32.dart';
import 'package:hotp/hotp.dart';
import 'package:protobuf/protobuf.dart';

import '../entities/account.entity.dart';
import '../entities/parse_account.dart';

/// A single bounded Google Authenticator migration QR fragment.
/// The format is an unofficial compatibility schema, not a Google API.
class MigrationFragment(
  final int batchId,
  final int batchSize,
  final int batchIndex,
  final List<AccountEntity> accounts,
  final Uint8List _payload,
) {}

const _maxEncodedLength = 65536;
const _maxAccounts = 100;
const _maxFragments = 50;

/// Holds one batch in memory until all fragments are validated or cancelled.
class MigrationBatch() {
  final Map<int, MigrationFragment> _fragments = {};
  int? _id;
  int? _size;

  int get received => _fragments.length;
  int? get expected => _size;
  bool get complete => _size != null && received == _size;

  /// Returns false for an identical repeat; conflicting scans fail closed.
  bool add(MigrationFragment fragment) {
    if (_id != null &&
        (_id != fragment.batchId || _size != fragment.batchSize)) {
      throw const FormatException('This QR belongs to a different batch.');
    }
    final previous = _fragments[fragment.batchIndex];
    if (previous != null) {
      if (!_sameBytes(previous._payload, fragment._payload)) {
        throw const FormatException('Conflicting batch fragment.');
      }
      return false;
    }
    final total = _fragments.values.fold<int>(
      0,
      (sum, f) => sum + f.accounts.length,
    );
    if (total + fragment.accounts.length > _maxAccounts) {
      throw const FormatException('Too many accounts in batch.');
    }
    _id = fragment.batchId;
    _size = fragment.batchSize;
    _fragments[fragment.batchIndex] = fragment;
    return true;
  }

  List<AccountEntity> get accounts {
    if (!complete) throw StateError('Batch is incomplete.');
    return List.unmodifiable([
      for (var i = 0; i < _size!; i++) ..._fragments[i]!.accounts,
    ]);
  }

  void clear() {
    _fragments.clear();
    _id = null;
    _size = null;
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

MigrationFragment parseGoogleMigration(String value) {
  if (value.length > _maxEncodedLength ||
      RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value)) {
    throw const FormatException('Invalid or oversized migration URI.');
  }
  try {
    final uri = Uri.parse(value);
    if (uri.scheme != 'otpauth-migration' ||
        uri.host != 'offline' ||
        uri.path.isNotEmpty ||
        uri.hasFragment ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.queryParametersAll['data']?.length != 1 ||
        uri.queryParametersAll.length != 1) {
      throw const FormatException('Invalid migration URI.');
    }
    // A literal plus in an unescaped QR query is interpreted as a space by Uri.
    final encoded = uri.queryParameters['data']!.replaceAll(' ', '+');
    final bytes = base64.decode(base64.normalize(encoded));
    if (bytes.isEmpty || bytes.length > _maxEncodedLength) {
      throw const FormatException('Invalid migration payload size.');
    }
    return _readFragment(bytes);
  } on FormatException catch (e) {
    if (e.source == null && !e.message.startsWith('Invalid character')) rethrow;
    throw const FormatException('Invalid migration encoding.');
  } catch (_) {
    // Never expose URI, protobuf payload, or encoded secret in diagnostics.
    throw const FormatException('Invalid migration payload.');
  }
}

MigrationFragment _readFragment(Uint8List bytes) {
  final reader = CodedBufferReader(
    bytes,
    sizeLimit: _maxEncodedLength,
    recursionLimit: 4,
  );
  final accounts = <AccountEntity>[];
  final seen = <int>{};
  int? version, size;
  // Protobuf scalar zero values may be omitted in proto3 encodings.
  var index = 0, id = 0;
  while (!reader.isAtEnd()) {
    final tag = reader.readTag();
    final field = tag >> 3, wire = tag & 7;
    if (field == 1) {
      if (wire != 2 || accounts.length >= _maxAccounts)
        throw const FormatException('Invalid account list.');
      accounts.add(_readAccount(reader.readBytes()));
    } else if (field >= 2 && field <= 5) {
      if (wire != 0 || !seen.add(field))
        throw const FormatException('Invalid batch metadata.');
      final value = reader.readInt32();
      switch (field) {
        case 2:
          version = value;
        case 3:
          size = value;
        case 4:
          index = value;
        case 5:
          id = value;
      }
    } else {
      _skipUnknown(reader, tag, wire);
    }
  }
  if (version != 1)
    throw const FormatException('Unsupported migration version.');
  if (size == null ||
      size < 1 ||
      size > _maxFragments ||
      index < 0 ||
      index >= size ||
      accounts.isEmpty) {
    throw const FormatException('Invalid batch metadata.');
  }
  return MigrationFragment(
    id,
    size,
    index,
    List.unmodifiable(accounts),
    Uint8List.fromList(bytes),
  );
}

void _skipUnknown(CodedBufferReader reader, int tag, int wire) {
  if (wire == 3 || wire == 4 || !reader.skipField(tag)) {
    throw const FormatException('Unsupported protobuf field.');
  }
}

AccountEntity _readAccount(Uint8List bytes) {
  final reader = CodedBufferReader(
    bytes,
    sizeLimit: _maxEncodedLength,
    recursionLimit: 4,
  );
  final seen = <int>{};
  Uint8List? secret;
  String? name, issuer;
  int? algorithm, digits, type;
  var counter = BigInt.zero;
  while (!reader.isAtEnd()) {
    final tag = reader.readTag();
    final field = tag >> 3, wire = tag & 7;
    if (field >= 1 && field <= 7) {
      if (!seen.add(field))
        throw const FormatException('Repeated account field.');
      if (field <= 3) {
        if (wire != 2) throw const FormatException('Invalid account field.');
        switch (field) {
          case 1:
            secret = reader.readBytes();
          case 2:
            name = utf8.decode(reader.readBytes());
          case 3:
            issuer = utf8.decode(reader.readBytes());
        }
      } else {
        if (wire != 0) throw const FormatException('Invalid account field.');
        switch (field) {
          case 4:
            algorithm = reader.readEnum();
          case 5:
            digits = reader.readEnum();
          case 6:
            type = reader.readEnum();
          case 7:
            counter = BigInt.parse(reader.readInt64().toString());
        }
      }
    } else {
      _skipUnknown(reader, tag, wire);
    }
  }
  if (secret == null ||
      secret.isEmpty ||
      secret.length > 256 ||
      name == null ||
      name.isEmpty) {
    throw const FormatException('Missing account name or secret.');
  }
  final hash = switch (algorithm) {
    1 => 'SHA1',
    2 => 'SHA256',
    3 => 'SHA512',
    _ => throw const FormatException('Unsupported migration algorithm.'),
  };
  final width = switch (digits) {
    1 => '6',
    2 => '8',
    _ => throw const FormatException('Unsupported migration digit count.'),
  };
  final kind = switch (type) {
    1 => AccountType.HOTP,
    2 => AccountType.TOTP,
    _ => throw const FormatException('Unsupported migration account type.'),
  };
  if (kind == .HOTP &&
      (counter < BigInt.zero || counter > BigInt.from(Hotp.maxCounter))) {
    throw const FormatException('Invalid HOTP counter.');
  }
  // The Google label often contains an issuer prefix; only strip a matching one.
  final service = issuer ?? '';
  final label = service.isNotEmpty && name.startsWith('$service:')
      ? name.substring(service.length + 1)
      : name;
  return accountFromFields(
    type: kind,
    issuer: service,
    name: label,
    secret: base32.encode(secret),
    algorithm: hash,
    digits: width,
    counter: counter.toString(),
  );
}
