# OOTP

OOTP (Open One-time Password) is a supports multiple programming languages. The generated one-time passwords are fully compliant with HOTP (HMAC-based One-time Password) and TOTP (Time-based One-time Password). 🚀It's easy to use!

## Introduction

The [OOTP for Node.js](https://npmjs.com/package/ootp) module is a TypeScript implementation of the [OOTP](https://github.com/bytegem/ootp) library.

## Features

  * Generate OOTP passwords for multiple programming languages
  * 100% Open source
  * HOTP
  * TOTP
  * [RFC 4226](https://tools.ietf.org/html/rfc4226) compliant
  * [RFC 6238](https://tools.ietf.org/html/rfc6238) compliant

## Installation

  * Install via [npm](https://www.npmjs.com/): `npm install ootp`
  * Install via [yarn](https://yarnpkg.com/): `yarn add ootp`

## Usage

You can use the library in your TypeScript or JavaScript projects.

> 💡Tips: You need to install **implementation Base32** module for you project.
>
> Example use [thirty-two](https://github.com/chrisumbel/thirty-two) module.

```typescript
import base32 from 'thirty-two';
import { TOTP } from 'ootp';

const base32_encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q";
const base32_decoded_secret = base32.decode(base32_encooded_secret);

/// Create a TOTP
const totp = new TOTP({ secret: base32_decoded_secret });

/// Make a OTP code.
const otp = totp.make();

/// Dispaly the OTP code.
console.log(otp);
```

## Examples

  * [TOTP - Node.js using TypeScript example](https://github.com/bytegem/ootp/tree/main/examples/node-typescript-example)

## Documentation

 * `TOTP` class
    * `make` - Generate OTP code
    * `check` - Check OTP code
 * `HOTP` class
    * `make` - Generate OTP code
    * `check` - Check OTP code

## License

The OOTP is licensed under the [MIT license](https://github.com/bytegem/ootp/blob/main/LICENSE).
