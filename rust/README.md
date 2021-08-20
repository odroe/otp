# OOTP

OOTP (Open One-time Password) is a supports multiple programming languages. The generated one-time passwords are fully compliant with HOTP (HMAC-based One-time Password) and TOTP (Time-based One-time Password). 🚀It's easy to use!

[![Rust](https://github.com/odroe/ootp/actions/workflows/rust.yml/badge.svg)](https://github.com/odroe/ootp/actions/workflows/rust.yml)
![crates.io version](https://img.shields.io/crates/v/ootp?style=flat-square)

## Introduction

The [OOTP for Rust](https://crates.io/crates/ootp) library is a [Rust](https://www.rust-lang.org/) implementation of the [OOTP](https://github.com/Odroe/ootp) library.

## Features

- Generate one-time passwords for multiple languages
- 100% Open source
- HOTP
- TOTP
- [RFC 4226](https://tools.ietf.org/html/rfc4226)
- [RFC 6238](https://tools.ietf.org/html/rfc6238)

## Installation

Add the following line to your Cargo.toml file:

```toml
[dependencies]
ootp = "0.0.6"
```

## Get started

```rust
use ootp::*;

fn main() {
   let secret = "Base32 decoded secret";
   let totp = Totp::secret(
       secret,
       CreateOption::Default
   );
   let otp = totp.make(); // Generate a one-time password
   println!("{}", otp); // Print the one-time password
}
```

## Examples

- [OOTP for Rust example](https://github.com/Odroe/ootp/tree/main/examples/rust-example)

## Documentation

- [Rust docs.rs page](https://docs.rs/ootp)

## License

The OOTP for Rust library is licensed under the [MIT license](https://github.com/Odroe/ootp/blob/main/LICENSE).
