/*!
## ootp
Fast and easy HOTP and TOTP implementation.

The [OOTP for Rust](https://crates.io/crates/ootp) library is a [Rust](https://www.rust-lang.org/) implementation of the [OOTP](https://github.com/odroe/ootp) library.
*/

#![forbid(unsafe_code)]

/// Constants module.
pub mod constants;
/// HOTP is a HMAC-based one-time password algorithm.
pub mod hotp;
/// TOTP is a Time-based one-time password algorithm, with a time value as moving factor.
pub mod totp;
// Re-export hmacsha to handle different SHA algorithms.
pub use hmacsha;

#[cfg(test)]
mod tests {
    use crate::constants::*;
    use crate::totp::{CreateOption, Totp};

    #[test]
    fn rust_example_test() {
        use base32;

        let encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q"; // The secret key is a base32 encoded string
        let secret_vec =
            base32::decode(base32::Alphabet::RFC4648 { padding: false }, encoded_secret).unwrap();
        let secret = String::from_utf8(secret_vec).unwrap();
        let totp = Totp::secret(&secret, CreateOption::Default);

        let otp_auth_uri = "otpauth://totp/{issuer}:{account}?secret={secret}&issuer={issuer}&period={period}&digits={digits}"
            .replace("{issuer}", "OOTP")
            .replace("{account}", "Tester")
            .replace("{secret}", encoded_secret)
            .replace("{period}", &format!("{}", DEFAULT_PERIOD))
            .replace("{digits}", &format!("{}", DEFAULT_DIGITS));

        let top = "790749";

        println!("valid: {:?}", totp.check(top, None));
        let otp = totp.make();
        println!("otp: {:?}", otp);
        println!("uri: {:?}", otp_auth_uri);
        assert!(totp.check(&otp, None))
    }

    #[test]
    fn rust_readme_example() {
        let secret = "Base32 decoded secret";
        let totp = Totp::secret(secret, CreateOption::Default);
        let otp = totp.make(); // Generate a one-time password
        println!("{}", otp); // Print the one-time password
    }
}
