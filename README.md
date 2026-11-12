# Open Authenticator

Flutter authenticator for SHA1 TOTP accounts; HOTP and other algorithms are not
supported by the app. Requires Flutter 3.50+ / Dart 3.14+, iOS 15+ or Android 7+.

## Development

```sh
flutter pub get
flutter analyze
flutter test
(cd pub/hotp && dart test --platform vm,node)
(cd pub/totp && dart test --platform vm,node)
```

Keep application ID `odroe.ootp.authenticator` for in-place upgrades. Configure
production signing separately; never commit credentials or real OTP databases.
Tests use public test vectors only.

## Storage and migration

New writes use SQLite. Legacy Hive data is read from copies, imported in a
transaction and verified before switching; original Hive files are retained.
Failed migration offers retry without clearing accounts. Do not uninstall or
clear storage to resolve an error. Physically damaged Hive files may still need
recovery; migration does not repair them. Downgrading reads stale Hive data.

## Security

SQLite and retained Hive files are not application-level encrypted. System
backups and Android device transfer remain enabled and may include OTP seeds.
Protect backups and destination devices; there is no cloud-sync service.
Deleting an account does not erase retained Hive copies or guarantee secure
erasure. Temporary migration copies are normally removed, but interruption can
leave them until OS cleanup. Physical-device file protection is not audited.

## Workspace

The root `pubspec.yaml` is both the Flutter application's manifest and the Dart
workspace definition. Run `flutter pub get` from the repository root to resolve
all three packages with a single root lockfile. Workspace dependencies resolve to
the local packages while retaining their published version constraints.

| Package | Source | Description |
| --- | --- | --- |
| [hotp](https://pub.dev/packages/hotp) | [pub/hotp](pub/hotp/) | HMAC-based one-time passwords ([RFC 4226](https://www.rfc-editor.org/rfc/rfc4226)) |
| [totp](https://pub.dev/packages/totp) | [pub/totp](pub/totp/) | Time-based one-time passwords ([RFC 6238](https://www.rfc-editor.org/rfc/rfc6238)) |

The library packages require Dart 3.13 or newer. Working
on the complete workspace requires the Flutter/Dart versions listed above.
Node.js is required for the package JavaScript tests.

## License

[MIT](LICENSE)
