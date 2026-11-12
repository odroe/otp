## 0.2.0

- Default to SHA1, six digits, and a positive whole-second `Duration` period.
- Use `generate({at})` for explicit or current time and replace boolean
  `validate` with `verify(code, {at, window})`, returning the matching step.
- Support symmetric verification windows, preferring current, nearest, then past
  matches. Verification does not consume codes or persist state.
- Return precise `Duration` values from `remaining` and `remainingAt`, including
  for large JavaScript timestamps. Return a full period at exact boundaries.
- Reject pre-epoch timestamps, invalid periods, and invalid windows at runtime.
  Limit JavaScript periods to 9007199254 seconds to preserve microsecond precision.
- Make `Totp` final, retain immutable key snapshots, and depend on HOTP 0.2.
- Restrict the Base32 factory to canonical RFC 4648 and remove Base32 re-exports
  and the encoding option. Retain the `Algorithm` export.

## 0.1.0

* ⚠️ Update Dart SDK to `^3.4.3`
* *feat*:Support remaing time

## 0.0.1

- Initial release
