# HMAC-based One-time Password (HOTP)

This is an implementation of the HOTP algorithm as specified in [RFC 4226](https://tools.ietf.org/html/rfc4226).

[![pub version](https://img.shields.io/pub/v/hotp.svg)](https://pub.dev/packages/hotp)

## Installation

```bash
dart pub add hotp
```

## Usage

```dart
final hotp = Hotp(secret: '12345678901234567890'.codeUnits);

// Generate a HOTP
final password = hotp.generate(counter: 0); // 755224
```

### Base32 encoding

```dart
final hotp = Hotp.fromBase32('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');

print(hotp.generate(counter: 0)); // 755224
```

## Supported algorithms

- SHA1 - default, as specified in RFC 4226
- SHA256
- SHA512

## APIs

### Constructor parameters

| Name        | Type        | Description                       |
| ----------- | ----------- | --------------------------------- |
| `secret`    | `List<int>` | The secret key.                   |
| `algorithm` | `Algorithm` | The algorithm to use.             |
| `digits`    | `int`       | The number of digits to generate. |

If you want to use a Base32 encoded secret, use the `fromBase32` constructor.

| Name        | Type        | Description                       |
| ----------- | ----------- | --------------------------------- |
| `secret`    | `String`    | The Base32 encoded secret key.    |
| `digits`    | `int`       | The number of digits to generate. |
| `algorithm` | `Algorithm` | The algorithm to use.             |
| `encoding`  | `Encoding`  | The encoding to use.              |

### Methods

| Name       | Return type | Description                             |
| ---------- | ----------- | --------------------------------------- |
| `generate` | `int`       | Generates a HOTP for the given counter. |
| `validate` | `bool`      | Validates a HOTP for the given counter. |

## Exported other package types

| Name       | Type    | Description                       |
| ---------- | ------- | --------------------------------- |
| `base32`   | `class` | Base32 encoding and decoding util |
| `Encoding` | `int`   | Base32 encoding and decoding alg  |

## License

The project is licensed under the MIT license.
