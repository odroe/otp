/*!
## ootp
Fast and easy HOTP and TOTP implementation.

The [OOTP for Rust](https://crates.io/crates/ootp) library is a [Rust](https://www.rust-lang.org/) implementation of the [OOTP](https://github.com/bytegem/ootp) library.
*/

/// Constants module.
pub mod constants;
/// HOTP is a HMAC-based one-time password algorithm.
pub mod hotp;
/// TOTP is a HOTP-based one-time password algorithm, with a time value as moving factor.
pub mod totp;
