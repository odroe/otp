# HOTP

An immutable [RFC 4226](https://www.rfc-editor.org/rfc/rfc4226) generator for Dart,
with SHA1, SHA256, and SHA512 support. Requires Dart 3.13 or later.

## Usage

```sh
dart pub add hotp
```

```dart
import 'package:hotp/hotp.dart';

void main() {
  final hotp = Hotp.fromBase32(secret: 'JBSWY3DPEHPK3PXP');
  print(hotp.generate(1)); // 996554
  print(hotp.verify('996554', 1)); // 1
  print(hotp.verify('996554', 0, window: 1)); // 1
  print(hotp.verify('996554', 0)); // null
}
```

`Hotp(secret: bytes, algorithm: .sha1, digits: 6)` accepts raw key bytes.
The key is copied into an unmodifiable list; modifying the input afterward does
not change generated codes. Keys are never repeated or truncated. Use randomly
generated keys of at least 128 bits for new accounts; shorter existing keys are
supported. Never log or expose secret bytes.

`fromBase32` accepts RFC 4648 ASCII letters in either case, with or without valid
padding. Whitespace, invalid alphabet characters, noncanonical trailing bits,
and invalid lengths or padding throw `FormatException`.

## Counters and verification

- `generate(int counter)` returns a zero-padded decimal `String`.
- `verify(String code, int counter, {int window = 0})` returns the first matching
  counter or `null`. It searches `counter` through `counter + window`, inclusive.
- Defaults are SHA1 and six digits; supported digit counts are 6, 7, and 8.
- Counters range from zero through `Hotp.maxCounter`: 2^63 - 1 on native runtimes
  and 2^53 - 1 on JavaScript. The full unsigned 64-bit range is not supported.
- Empty or non-byte keys throw `ArgumentError`. Invalid digits, counters, or
  verification windows throw `RangeError`, including windows that overflow.
- Malformed codes return `null`, but do not bypass counter/window validation.

Neither method changes or persists counters. After verification, the application
must atomically persist advancement beyond the matched counter to prevent replay.
At `Hotp.maxCounter`, no next counter is representable: retire or replace that
credential instead of overflowing. Enforce attempt limits and use a small,
application-controlled window. A larger window increases work and guessing risk.

## Migrating from 0.1

- Replace `validate(code, counter, breadth: n)` with
  `verify(code, counter, window: n)`. Check `!= null` for a boolean result, or use
  the returned counter to advance application state.
- `Hotp` is final and cannot be subclassed; its key snapshot is immutable.
- `Algorithm` contains only `sha1`, `sha256`, and `sha512`. The `hash`, `length`,
  and `repeat` members and public `Hotp.hmac` implementation detail are removed.
- Base32 helpers and `Encoding` are no longer re-exported. `fromBase32` handles
  RFC 4648 only; decode other formats explicitly before supplying raw bytes.
- Configuration errors now throw at runtime instead of relying on assertions.
  The digit range is restricted to 6–8 and Base32 input is checked strictly.
