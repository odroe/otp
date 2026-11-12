# Open Authenticator

Flutter authenticator app in the `odroe/otp` monorepo. The HOTP and TOTP packages
remain separate packages; this app update does not restore or redesign OOTP.

## Development

Use Flutter 3.50.0 (Dart 3.14.0) or a compatible stable toolchain meeting
`pubspec.yaml`. This toolchain targets iOS 15+ and Android API 24+ (Android 7).
See [validation results and limits](docs/validation.md) and the
[dependency audit](docs/dependencies.md). Run from this directory:

```sh
flutter pub get
flutter analyze
flutter test
```

The iOS bundle ID and Android application ID remain
`odroe.ootp.authenticator`. Do not change these identifiers or uninstall an old
installation when testing an in-place data migration.

## Storage update

New account changes use the Dart `sqlite3` package. At first launch the app reads
copies of the legacy Hive `accounts.hive` / `accounts.hivec` files, imports every
record in a transaction, compares every key and field, reopens the database and
checks it before marking migration complete. The original Hive files stay in
place. Migration failure blocks access and offers retry instead of presenting
an empty account list or clearing data.

This is not a damaged-file recovery tool. A physically damaged Hive file may
still prevent migration. Keep the app installed and preserve its original data;
do not clear storage or reinstall to work around a migration error. After
migration, old Hive data is a retained snapshot, not a live mirror of SQLite.
Downgrading to the historical app would show stale data.

The current UI supports SHA1 TOTP accounts. Unsupported HOTP/algorithm QR codes
are rejected instead of being silently interpreted as SHA1 TOTP. Existing
malformed entries are retained and shown with an error rather than crashing the
whole list.

## Distribution

This repository update is not an App Store or Play Store release. Signing,
device tests and store submission are separate steps. Never commit real OTP
secrets or device databases. Tests use public RFC test vectors only.

## Security boundaries

SQLite and retained Hive files are not application-level encrypted. They rely
on the device's app sandbox and operating-system data protection. This change
does not add a cloud-sync service or change the original Documents storage
location; normal device backup policy still applies. Device-level file
protection has not been audited on a physical iPhone in this iteration.

Deleting an account removes its active SQLite row, not the retained Hive
snapshot, and is not a secure-erasure guarantee. Migration decode copies use
the app's temporary directory (not Documents); normal completion removes them,
but an interrupted process can leave temporary copies until OS cleanup.
Keep device backups and access controls protected accordingly.
