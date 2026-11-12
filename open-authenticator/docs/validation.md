# Validation: 2026-11-12

## Passed

Toolchain: Flutter 3.47.8 stable, Dart 3.13.7, Xcode 27.2, CocoaPods 1.17.0.

- `flutter analyze`: no issues.
- `flutter test`: all 32 tests passed on the final source and dependency lock.
- `flutter build ios --release --no-codesign`: passed. The unsigned product keeps
  bundle ID `odroe.ootp.authenticator`, requires iOS 15, and includes SQLite's
  native framework.
- `flutter build ios --simulator --debug`: passed.
- Isolated iOS 26.5 / iPhone 17 Pro simulator: installed and launched the app with
  a synthetic Hive 2.0.4 fixture seeded before first launch. All three records,
  including a nullable name, migrated and rendered. The SQLite migration marker
  was complete, `PRAGMA integrity_check` returned `ok`, and the original Hive
  SHA256 was unchanged. Temporary decoding copies were cleaned up.
- Relaunch and in-place replacement of the test app preserved records.
- Regression tests cover null-name search/rendering, lowercase legacy secrets
  without modifying their stored value, period/digit changes, migration failure
  and retry, interrupted import, original-file preservation, native SQLite
  rollback, and unchanged OOTP RFC 6238 SHA1 vectors.

## Compatibility

This toolchain requires iOS 15 (raised from the historical project's iOS 12.1)
and Android API 24 / Android 7 (raised from API 16). Android API 24 is declared
by the Flutter engine itself, not just selected by the app template.

The old OOTP dependency remains version 0.1.1; its discontinued notice is known.
No HOTP, TOTP or OOTP package source was changed. The final app dependency lock
updates obsolete transitive packages that no longer compile under modern Dart.

## Not verified / not released

Android APK compilation was attempted. A transient distribution download error
resolved on retry; Gradle then started its daemon but stopped making observable
progress. The attempt was stopped. No Android compiler pass or failure was
established, and no Android runtime validation was performed.

Physical iPhone operation, real camera scanning, full App Store upgrade delivery,
and power-loss/fsync behavior are not verified. The simulator checks used public
RFC test seeds only, never real user credentials. No real user database was read
or changed. Nothing was signed or submitted to an app store.

No new entitlements, custom file-protection settings or backup exclusions were
added. Hardware file protection was not audited on a physical iPhone. See the
README's security boundaries; this is not an encrypted-vault or secure-erasure
implementation.
