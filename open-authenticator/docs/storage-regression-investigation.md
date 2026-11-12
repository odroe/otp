# Historical storage / rendering regression investigation

Baseline: `b40d08114ed6b881b4270010ccd4e9a99d7095e7`, app 0.1.0+1.
Locked persistence dependencies: Hive 2.0.4, hive_flutter 1.1.0,
path_provider 2.0.2. Box: `accounts`; adapter IDs 0 (type), 1 (account).
iOS bundle ID: `odroe.ootp.authenticator`.

## Reproduced, not inferred

Using Dart 2.19.6 and the historical account adapters / Hive 2.0.4:

* Three synthetic accounts, one with `name == null`, survived three close/open
  cycles with all records intact.
* Evaluating the historical card's `account.name!.isNotEmpty` and search's
  `account.name!.toLowerCase()` on that persisted record threw `_CastError`.
* The historical scanner intentionally makes `name` null for an issuer-only
  QR label. Thus adding a legitimate item can break the screen while leaving
  the underlying database intact. This does **not** establish the cause of
  every historical device incident; the original device file would be needed.
* Appending three junk bytes to a **synthetic** box and opening with defaults
  caused Hive to print `Recovering corrupted box.` and truncate those bytes.
* Strict open rejected that deliberately damaged box, but Hive 2.0.4 also
  completes an internal unobserved future with the error. An ordinary outer
  `try/catch` does not by itself handle this extra asynchronous error.

Parser regression tests cover valid labels and malformed or unsupported inputs. The final Flutter tests and iOS builds were subsequently run on macOS; see
[validation results](validation.md) for the exact checks and remaining limits.

## Data preservation constraints

Do not clear/recreate the old box or treat a failed read as an empty database.
Hive 2.0.4 defaults to destructive tail recovery. Its backend also deletes an
existing `.hivec` compaction file when `.hive` exists, even with crash recovery
disabled. Preserve both files **before** opening originals for any recovery
attempt. Work on copies and never print OTP secrets to diagnostic logs.

Current fixes leave the historical adapter IDs/fields and stored records
unchanged. Malformed legacy records display a per-item error instead of
being silently removed. No real user database has been inspected or repaired.
The SQLite implementation now imports strict-read copies of Hive originals,
validates every record in a transaction, closes/reopens SQLite for verification,
and only then enables new SQLite writes. Thirteen isolated storage tests pass,
including a real Hive 2.0.4 synthetic binary fixture. Migration failures block
access and preserve originals for retry; physical corruption is not silently
repaired or discarded. Preserve the app bundle ID and historical
storage location so an in-place update can find existing data.

## Tests to run with the selected Flutter toolchain

```
flutter test test/parse_account_test.dart test/persistence_regression_test.dart
flutter analyze
```

Also verify on iOS: add several valid QR accounts including issuer-only labels,
search for a nonmatching term, replace an existing account, force-stop/relaunch,
and update an installed historical build without uninstalling it. Test invalid
QR codes and an invalid legacy period/secret without losing healthy entries.
Use public RFC test seeds or synthetic data only.
