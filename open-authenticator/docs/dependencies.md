# Dependency audit: 2026-11-12

The app's dependencies were upgraded with `flutter pub upgrade` and then audited
on macOS with `flutter pub outdated`, using Flutter 3.50.0 / Dart 3.14.0.
Every direct and development dependency is at its latest stable release.
All packages' Current, Upgradable and Resolvable versions match; no further
compatible update was available at the time of the audit.

| Dependency | Locked version |
| --- | --- |
| base32 | 2.2.0 |
| cupertino_icons | 2.0.0 |
| cupertino_ui | 1.1.6 |
| flutter_launcher_icons | 0.14.4 |
| hive | 2.2.3 |
| mobile_scanner | 7.5.0 |
| ootp | 0.1.1 |
| path_provider | 2.1.6 |
| percent_indicator | 4.2.5 |
| sqlite3 | 3.9.1 |
| url_launcher | 6.3.3 |

`flutter` and `flutter_test` come from the selected Flutter SDK, not independent
hosted package releases. The committed lockfile records exact transitive
versions and hosted-package checksums.

## Intentional compatibility boundaries

- **Hive 2.2.3:** retained only for legacy data decoding. All active writes use
  SQLite. Compatibility with an actual Hive 2.0.4 synthetic binary fixture is
  covered by tests. Do not substitute an incompatible prerelease or fork merely
  to make a version number larger.
- **OOTP 0.1.1:** still the latest published version, although marked discontinued.
  The algorithm is unchanged in this iteration and is checked against RFC 6238
  SHA1 vectors. Reworking the HOTP/TOTP/OOTP packages is outside this app update.
- **SDK/tool-pinned transitive packages:** Flutter pins
  `material_color_utilities` 0.13.0; `flutter_test` pins `test_api` 0.7.14;
  `flutter_launcher_icons` 0.14.4 requires `cli_util` ^0.4.1 (resolved 0.4.2).
  Newer releases shown in the Latest column cannot currently be resolved with
  these compatible constraints. No dependency override was added to bypass them.

The obsolete `hive_flutter` runtime wrapper and `flutter_barcode_scanner` were
removed. Hive adapters are retained for decoding historical records; no
regeneration or schema renumbering is performed.

## Official Cupertino extraction

Flutter 3.50 deprecates `package:flutter/cupertino.dart` in favor of
`package:cupertino_ui/cupertino_ui.dart`. The app follows that official migration
with `cupertino_ui` 1.1.6, published by the verified `flutter.dev` publisher from
[flutter/packages](https://github.com/flutter/packages/tree/main/packages/cupertino_ui).
This is the Flutter team's BSD-3-Clause package, not an unrelated UI replacement.
Its Flutter Authors copyright and license are included in the built app's
`NOTICES.Z`. Direct runtime dependencies were checked for legacy Cupertino theme
and localization usage; no legacy compatibility bridge was needed.
