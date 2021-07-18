use crate::constants::{DEFAULT_BREADTH, DEFAULT_COUNTER, DEFAULT_DIGITS};
use hmacsha1::hmac_sha1;

/// Convert a `u64` value to an array of 8 elements of 8-bit.
fn u64_to_8_length_u8_array(input: u64) -> [u8; 8] {
    let mut bytes = [0_u8; 8];
    for (i, item) in bytes.iter_mut().enumerate().take(7) {
        *item = (input >> (i * 8)) as u8;
    }
    bytes.reverse();
    bytes
}

fn make_opt(secret: &[u8], digits: u32, counter: u64) -> String {
    let counter_bytes = u64_to_8_length_u8_array(counter);
    let digest = hmac_sha1(secret, &counter_bytes);
    let offset = digest[digest.len() - 1] as usize & 0x0f;
    let value = (u32::from(digest[offset]) & 0x7f) << 24
        | (u32::from(digest[offset + 1]) & 0xff) << 16
        | (u32::from(digest[offset + 2]) & 0xff) << 8
        | u32::from(digest[offset + 3]) & 0xff;
    let mut code = (value % 10_u32.pow(digits)).to_string();
    // Check whether the code is digits bits long, if not, use "0" to fill in the front
    if code.len() != (digits as usize) {
        code = "0".repeat((digits - (code.len() as u32)) as usize) + &code;
    }

    code
}

/// The Options for the `make` function.
pub enum MakeOption {
    /// The default case. `Counter = 0` and `Digits = 6`.
    Default,
    /// Specify the `Counter`.
    Counter(u64),
    /// Specify the desired number of `Digits`.
    Digits(u32),
    /// Specify both the `Counter` and the desired number of `Digits`.
    Full { counter: u64, digits: u32 },
}

/// The Options for the `check` function.
pub enum CheckOption {
    /// The default case. `Counter = 0` and `Breadth = 0`.
    Default,
    /// Specify the `Counter`.
    Counter(u64),
    /// Specify the desired number of digits.
    Breadth(u64),
    /// Specify both the `Counter` and the desired `Breadth`.
    Full { counter: u64, breadth: u64 },
}
/// The HOTP is a HMAC-based one-time password algorithm.
///
/// It takes one parameter, the shared secret between client and server.
pub struct Hotp<'a>(pub &'a str);

impl Hotp<'_> {
    /**
    Returns the one-time password as a `String`

    # Example #1

    ```
    use ootp::hotp::{Hotp, MakeOption};

    let hotp = Hotp("A strong shared secret");
    let code = hotp.make(MakeOption::Default);
    ```

    # Example #2

    ```
    use ootp::hotp::{Hotp, MakeOption};
    let hotp = Hotp("A strong shared secret");
    let code = hotp.make(MakeOption::Digits(8));
    ```
    */
    pub fn make(&self, options: MakeOption) -> String {
        match options {
            MakeOption::Default => make_opt(self.0.as_bytes(), DEFAULT_DIGITS, DEFAULT_COUNTER),
            MakeOption::Counter(counter) => make_opt(self.0.as_bytes(), DEFAULT_DIGITS, counter),
            MakeOption::Digits(digits) => make_opt(self.0.as_bytes(), digits, DEFAULT_COUNTER),
            MakeOption::Full { counter, digits } => make_opt(self.0.as_bytes(), digits, counter),
        }
    }
    /**
    Returns a boolean indicating if the one-time password is valid.

    # Example #1

    ```
    use ootp::hotp::{Hotp, MakeOption, CheckOption};

    let hotp = Hotp("A strong shared secret");
    let code = hotp.make(MakeOption::Default);
    let check = hotp.check(code.as_str(), CheckOption::Default);
    ```

    # Example #2

    ```
    use ootp::hotp::{Hotp, MakeOption, CheckOption};
    let hotp = Hotp("A strong shared secret");
    let code = hotp.make(MakeOption::Counter(2));
    let check = hotp.check(code.as_str(), CheckOption::Counter(2));
    ```
    */
    pub fn check(&self, otp: &str, options: CheckOption) -> bool {
        let (counter, breadth) = match options {
            CheckOption::Default => (DEFAULT_COUNTER, DEFAULT_BREADTH),
            CheckOption::Counter(counter) => (counter, DEFAULT_BREADTH),
            CheckOption::Breadth(breadth) => (DEFAULT_COUNTER, breadth),
            CheckOption::Full { counter, breadth } => (counter, breadth),
        };
        for i in (counter - breadth)..=(counter + breadth) {
            let code = self.make(MakeOption::Full {
                counter: i,
                digits: otp.len() as u32,
            });
            if code == otp {
                return true;
            }
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::{CheckOption, Hotp, MakeOption};

    #[test]
    fn make_test() {
        let hotp = Hotp("A strong shared secret");
        let code1 = hotp.make(MakeOption::Default);
        let code2 = hotp.make(MakeOption::Default);
        assert_eq!(code1, code2);
    }
    /// Taken from [RFC 4226](https://datatracker.ietf.org/doc/html/rfc4226#appendix-D)
    #[test]
    fn make_test_correcteness() {
        use hex;

        let secret = "12345678901234567890";
        let hotp = Hotp(secret);
        let hex_string = hex::encode(secret);
        assert_eq!(
            format!("0x{}", hex_string),
            "0x3132333435363738393031323334353637383930"
        );
        let code = hotp.make(MakeOption::Counter(0));
        assert_eq!(code, "755224");
        let code = hotp.make(MakeOption::Counter(1));
        assert_eq!(code, "287082");
        let code = hotp.make(MakeOption::Counter(2));
        assert_eq!(code, "359152");
        let code = hotp.make(MakeOption::Counter(3));
        assert_eq!(code, "969429");
        let code = hotp.make(MakeOption::Counter(4));
        assert_eq!(code, "338314");
        let code = hotp.make(MakeOption::Counter(5));
        assert_eq!(code, "254676");
        let code = hotp.make(MakeOption::Counter(6));
        assert_eq!(code, "287922");
        let code = hotp.make(MakeOption::Counter(7));
        assert_eq!(code, "162583");
        let code = hotp.make(MakeOption::Counter(8));
        assert_eq!(code, "399871");
        let code = hotp.make(MakeOption::Counter(9));
        assert_eq!(code, "520489");
    }

    #[test]
    fn check_test() {
        let hotp = Hotp("A strong shared secret");
        let code = hotp.make(MakeOption::Default);
        let check = hotp.check(code.as_str(), CheckOption::Default);
        assert!(check);
    }

    #[test]
    fn check_test_counter() {
        let hotp = Hotp("A strong shared secret");
        let code = hotp.make(MakeOption::Counter(42));
        let check = hotp.check(code.as_str(), CheckOption::Counter(42));
        assert!(check);
    }

    #[test]
    fn check_test_breadth() {
        let hotp = Hotp("A strong shared secret");
        let code = hotp.make(MakeOption::Counter(42));
        let check = hotp.check(
            code.as_str(),
            CheckOption::Full {
                counter: 42,
                breadth: 6,
            },
        );
        assert!(check);
    }

    #[test]
    fn check_test_counter_and_breadth() {
        let hotp = Hotp("A strong shared secret");
        let code = hotp.make(MakeOption::Counter(42));
        let check = hotp.check(
            code.as_str(),
            CheckOption::Full {
                counter: 42,
                breadth: 6,
            },
        );
        assert!(check);
    }
}
