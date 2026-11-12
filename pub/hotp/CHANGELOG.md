## 0.2.0

- Replace boolean `validate` with `verify(code, counter, {window})`, returning the
  first matching counter in an inclusive forward window or `null`.
- Make `Hotp` final and snapshot key bytes in an immutable list.
- Validate keys, 6–8 digit counts, counters, and verification windows at runtime.
- Strictly decode canonical RFC 4648 Base32, allowing ASCII case differences and
  optional padding, while rejecting invalid unused bits.
- Remove public HMAC internals, Algorithm helpers, Base32 re-exports, and the
  `fromBase32` encoding parameter.
- Preserve arbitrary nonempty key lengths and exact counter encoding on native
  and JavaScript runtimes. Require Dart 3.13 or later.

## 0.1.0

* ⚠️ Upgrade Dart SDK to `v3.4.3`

## 0.0.2

1. set default algorithm to SHA1

## 0.0.1

- Initial release.
