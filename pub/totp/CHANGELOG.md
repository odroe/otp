## Unreleased

- Adapt the implementation to HOTP 0.2 while retaining TOTP constructor and method
  signatures, defaults, and Base32 exports. Keys now use immutable snapshots and
  inherit HOTP runtime validation for nonempty bytes, 6–8 digits, and counters.

## 0.1.0

* ⚠️ Update Dart SDK to `^3.4.3`
* *feat*:Support remaing time

## 0.0.1

- Initial release
