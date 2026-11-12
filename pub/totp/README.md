# TOTP

An immutable [RFC 6238](https://www.rfc-editor.org/rfc/rfc6238) generator using
Unix-epoch time steps. Requires Dart 3.13 or later.

```sh
dart pub add totp
```

```dart
import 'package:totp/totp.dart';

void main() {
  final totp = Totp.fromBase32(secret: 'JBSWY3DPEHPK3PXP');
  final at = DateTime.fromMillisecondsSinceEpoch(30000, isUtc: true);
  print(totp.generate(at: at)); // 996554
  print(totp.verify('996554', at: at)); // 1
  print(totp.remainingAt(at)); // 0:00:30.000000
  print(totp.generate()); // A code for the current time.
}
```

## Configuration

Defaults are `algorithm: .sha1`, `digits: 6`, and
`period: const Duration(seconds: 30)`. SHA256 and SHA512 are also supported.
The digit count must be 6–8 and the period must be a positive whole number of
seconds. On JavaScript, the maximum period is 9007199254 seconds, keeping its
microseconds within the exact integer range; a larger period throws
`ArgumentError`. Native runtimes retain the full `Duration` range.
Invalid periods or keys throw `ArgumentError`; invalid digit counts
throw `RangeError`.

`Totp(secret: bytes)` snapshots nonempty byte keys without repeating or truncating
them. The exposed key list is immutable. Use randomly generated keys of at least
128 bits for new accounts and never expose them. Existing shorter keys remain
supported. `Totp.fromBase32` accepts canonical RFC 4648 ASCII Base32 in either
letter case, with optional valid padding. Whitespace, invalid lengths, padding,
alphabets, and nonzero unused bits throw `FormatException`.

## Time and verification

`generate({DateTime? at})` defaults to the current time. Time steps are
`floor(Unix seconds / period seconds)`: an exact boundary belongs to the next
step. Local and UTC representations of the same instant produce the same code.
Timestamps before the Unix epoch throw `ArgumentError`.

`verify(code, {DateTime? at, int window = 0})` returns a matching **time-step
number**, not an epoch timestamp, or `null`. It checks only the current step by
default. A window of 1 also checks the immediately previous and next steps.
When several steps match, the current step wins, then the nearest step, then the
past step for an equal-distance tie. Negative steps and steps beyond the runtime's
HOTP counter range are excluded. Invalid windows throw `RangeError` even for
malformed codes; otherwise malformed decimal codes return `null`.

Verification does not persist state or prevent replay. Applications must track
consumed steps per credential and enforce attempt limits. Keep the window small
and application-controlled: a larger window increases cost and guessing risk.
Window values must be nonnegative exact integers, at most 2^63 - 1 on native
runtimes or 2^53 - 1 on JavaScript.

`remaining` and `remainingAt(DateTime at)` return a `Duration` with subsecond
precision. At an exact boundary they return the full period. No next-boundary
`DateTime` is constructed, avoiding overflow at the maximum supported date.

## Migrating from 0.1

- Defaults change from SHA256/eight digits to SHA1/six digits. Specify the old
  settings explicitly when retaining an existing credential's configuration.
- Replace integer `period: 30` with `period: const Duration(seconds: 30)`.
- Replace `generate(time)` with `generate(at: time)` and `now()` with `generate()`.
- Replace `validate(code, time)` with `verify(code, at: time) != null`. The new
  result identifies the matching time step; an optional window is symmetric.
- `remaining` and `remainingAt` return `Duration`, not integer seconds. For the
  former rounded-up seconds display, use
  `(remaining.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/
  Duration.microsecondsPerSecond`.
- `Totp` is final and cannot be subclassed. Keys are immutable snapshots and
  invalid inputs are checked at runtime.
- `Encoding` and `base32` are no longer exported, and the Base32 factory no longer
  takes an encoding option. Decode other formats explicitly before passing bytes.
