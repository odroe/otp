# Validation: 2026-11-12

## Passed

Toolchain: Flutter 3.50.0 stable, Dart 3.14.0, Xcode 27.2, CocoaPods 1.17.0.

- `flutter analyze`: no issues.
- `flutter test`: all 35 tests passed on the final source and dependency lock.
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
- Regression tests cover null-name and empty-issuer compatibility, lowercase legacy secrets
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

## Android validation

- `flutter build apk --release --target-platform android-arm64`: passed in
  22.2 seconds, with no excluded tasks.
- From `android`, `./gradlew :app:lintRelease -Ptarget-platform=android-arm64
  --no-daemon`: passed in 19 seconds, with **0 errors and 7 warnings**. These are
  one newer-Gradle-version suggestion, one redundant `drawable-v21` qualifier,
  and five existing launcher-icon shape warnings. The supported Flutter template
  toolchain and existing branding were not changed just to silence warnings.
- On a dedicated Android 35 ARM64 emulator, the final default-build APK imported
  three synthetic Hive records, rendered them (including a nullable name), marked
  migration complete, returned `ok` from SQLite's integrity check, and preserved
  the original Hive SHA256. Relaunch retained the records.
- The APK contains ARM64 native SQLite and Flutter AOT code, keeps the application
  ID, and targets Android API 36. Readback used a same-signature debug build
  installed while the release app was stopped, without running its older code,
  then restored the release build. No root access or security changes were used.

Earlier native-lint dependency downloads stalled. That download blocker was
resolved by fetching the same official artifacts, verifying their official
checksums, and reusing them in the build cache. Both the unmodified default build
and explicit native lint subsequently passed; no repository lint setting was
disabled. Other Android ABIs and Android physical devices remain unverified.

## Not verified / not released

Physical iPhone operation, real camera scanning, full App Store upgrade delivery,
and power-loss/fsync behavior are not verified. The simulator checks used public
RFC test seeds only, never real user credentials. No real user database was read
or changed. The iOS build was unsigned; the Android diagnostic APK used the
existing development/debug key. No production signing or app-store submission
was performed.

No new entitlements, custom file-protection settings or backup exclusions were
added. Hardware file protection was not audited on a physical iPhone. See the
README's security boundaries; this is not an encrypted-vault or secure-erasure
implementation.
