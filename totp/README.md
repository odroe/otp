# Time-based One-Time Password (TOTP)

This is an implementation of the TOTP algorithm as specified in [RFC 6238](https://tools.ietf.org/html/rfc6238).

[![pub version](https://img.shields.io/pub/v/totp.svg)](https://pub.dartlang.org/packages/totp)

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  totp: latest
```

Or install it from the command line:

```bash
dart pub add totp
```

## Usage

```dart
import 'package:totp/totp.dart';

final totp = Totp(secret: '12345678901234567890'.codeUnits);

print(totp.now());
```

If you want to use a base32 encoded secret, you can use the `fromBase32` constructor:

```dart
final totp = Totp.fromBase32(
  secret: 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
);
```

## APIs

| Method     | Return type | Description                                    |
| ---------- | ----------- | ---------------------------------------------- |
| `generate` | `String`    | Generates a new password with a `DateTime`     |
| `now`      | `String`    | Generates a new password with `DateTime.now()` |
| `validate` | `bool`      | Validates a password with a `DateTime`         |

## License

The project is licensed under the MIT license.
