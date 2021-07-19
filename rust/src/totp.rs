use crate::constants::{DEFAULT_DIGITS, DEFAULT_PERIOD};
use crate::hotp::{CheckOption, Hotp, MakeOption};
use std::time::SystemTime;

fn create_counter(period: u64) -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        / period
}

/// The TOTP is a Time-based one-time password algorithm, with a time value as moving factor.
///
/// It takes three parameter. Am `Hotp` istance, the desired number of digits and a time period.
pub struct Totp<'a> {
    pub hotp: Hotp<'a>,
    pub digits: u32,
    pub period: u64,
}
/// The Options for the TOTP's `make` function.
pub enum CreateOption {
    /// The default case. `Period = 30` seconds and `Digits = 6`.
    Default,
    /// Specify the desired number of `Digits`.
    Digits(u32),
    /// Specify the desired time `Period`.
    Period(u64),
    /// Specify both the desired time `Period` and the number of `Digits`.
    Full { digits: u32, period: u64 },
}

impl<'a> Totp<'a> {
    pub fn secret(secret: &'a str, option: CreateOption) -> Totp<'a> {
        let hotp = Hotp::new(secret);
        let (digits, period) = match option {
            CreateOption::Default => (DEFAULT_DIGITS, DEFAULT_PERIOD),
            CreateOption::Digits(digits) => (digits, DEFAULT_PERIOD),
            CreateOption::Period(period) => (DEFAULT_DIGITS, period),
            CreateOption::Full { digits, period } => (digits, period),
        };
        Totp {
            hotp,
            digits,
            period,
        }
    }
    /**
    This function returns a string of the one-time password

    # Example

    ```rust
    use ootp::totp::{Totp, CreateOption};

    let secret = "Base32 decoded secret";
    let totp = Totp::secret(
        secret,
        CreateOption::Default
    );

    let otp = totp.make(); // Generate a one-time password
    println!("{}", otp); // Print the one-time password
    ```

    */

    pub fn make(&self) -> String {
        self.hotp.make(MakeOption::Full {
            counter: create_counter(self.period),
            digits: self.digits,
        })
    }
    /**
    Returns a boolean indicating if the one-time password is valid.

    # Example #1

    ```
    use ootp::totp::{Totp, CreateOption};

    let secret = "A strong shared secret";
    let totp = Totp::secret(
        secret,
        CreateOption::Default
    );
    let otp = totp.make(); // Generate a one-time password
    let check = totp.check(otp.as_str(), None);
    ```

    # Example #2

    ```
    use ootp::totp::{Totp, CreateOption};

    let secret = "A strong shared secret";
    let totp = Totp::secret(
        secret,
        CreateOption::Digits(8)
    );
    let otp = totp.make(); // Generate a one-time password
    let check = totp.check(otp.as_str(), Some(42));
    ```
    */
    pub fn check(&self, otp: &str, breadth: Option<u64>) -> bool {
        self.hotp.check(
            otp,
            CheckOption::Full {
                counter: create_counter(self.period),
                breadth: breadth.unwrap_or(DEFAULT_PERIOD),
            },
        )
    }
}

#[cfg(test)]
mod tests {
    use super::{CreateOption, Totp};
    use crate::constants::DEFAULT_DIGITS;

    #[test]
    fn it_works() {
        let secret = "A strong shared secret";
        let totp = Totp::secret(secret, CreateOption::Default);
        let code = totp.make();
        assert_eq!(code.len(), DEFAULT_DIGITS as usize);
    }

    /// Taken from [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238#appendix-B)
    #[test]
    #[ignore = "Still To-do"]
    fn make_test_correcteness() {
        todo!()
    }
}
