# OOTP

OOTP (Open One-time Password) is a supports multiple programming languages. The generated one-time passwords are fully compliant with HOTP (HMAC-based One-time Password) and TOTP (Time-based One-time Password). 🚀It's easy to use!

## Introduction

The [OOTP for Rust](https://crates.io/crates/ootp) library is a [Rust](https://www.rust-lang.org/) implementation of the [OOTP](https://github.com/bytegem/ootp) library.

## Features

 * Generate one-time passwords for multiple languages
 * 100% Open source
 * HOTP
 * TOTP
 * [RFC 4226](https://tools.ietf.org/html/rfc4226)
 * [RFC 6238](https://tools.ietf.org/html/rfc6238)

## Installation

Add the following line to your Cargo.toml file:

```toml
[dependencies]
ootp = "0.2"
```

or use the following command:

```bash
$ cargo install ootp
```

## Get started
```rust
use ootp::TOTP

fn main() {
    let secret = String::from("Base32 decoded secret");
    let period = 30; // 30 seconds
    let digits = 6; // 6 digits

    let totp = TOTP::new(secret, digits, period);

    let otp = totp.make(); // Generate a one-time password
    println!("{}", otp); // Print the one-time password
}
```

## Examples

 * [OOTP for Rust example](https://github.com/bytegem/ootp/tree/main/examples/rust-example)

## Documentation

 * [Rust docs.rs page](https://docs.rs/ootp)

## License

The OOTP for Rust library is licensed under the [MIT license](https://github.com/bytegem/ootp/blob/main/LICENSE).
