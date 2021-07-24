use crate::constants::{DEFAULT_DIGITS, DEFAULT_PERIOD, DEFAULT_ALGORITHM};
use crate::hotp::{CheckOption, Hotp, MakeOption};
use hmacsha::ShaTypes;
use std::time::SystemTime;

fn create_counter(period: u64) -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        / period
}

/// The TOTP is a HOTP-based one-time password algorithm, with a time value as moving factor.
///
/// It takes four parameter. An `Hotp` istance, the desired number of digits, a time period and the SHA algorithm.
pub struct Totp<'a> {
    pub hotp: Hotp<'a>,
    pub digits: u32,
    pub period: u64,
    pub algorithm: &'a ShaTypes,
}
/// The Options for the TOTP's `make` function.
pub enum CreateOption<'a> {
    /// The default case. `Period = 30` seconds and `Digits = 6`.
    Default,
    /// Specify the desired number of `Digits`.
    Digits(u32),
    /// Specify the desired time `Period`.
    Period(u64),
    /// Specify both the desired time `Period` and the number of `Digits`.
    Full {
        digits: u32,
        period: u64,
        algorithm: &'a ShaTypes,
    },
    /// Specify the SHA algorihm
    Algorithm(&'a ShaTypes),
}

impl<'a> Totp<'a> {
    /// TOTP instance "private" constructor
    fn new(hotp: Hotp<'a>, digits: u32, period: u64, algorithm: &'a ShaTypes) -> Self {
        Self {
            hotp,
            digits,
            period,
            algorithm,
        }
    }

    /// TOTP instance constructor
    pub fn secret(secret: &'a str, option: CreateOption<'a>) -> Totp<'a> {
        let hotp = Hotp::new(secret);
        let (digits, period, algorithm) = match option {
            CreateOption::Default => (DEFAULT_DIGITS, DEFAULT_PERIOD, DEFAULT_ALGORITHM),
            CreateOption::Digits(digits) => (digits, DEFAULT_PERIOD, DEFAULT_ALGORITHM),
            CreateOption::Period(period) => (DEFAULT_DIGITS, period, DEFAULT_ALGORITHM),
            CreateOption::Full {
                digits,
                period,
                algorithm,
            } => (digits, period, algorithm),
            CreateOption::Algorithm(algorithm) => (DEFAULT_DIGITS, DEFAULT_PERIOD, algorithm),
        };
        Totp::new(hotp, digits, period, algorithm)
    }
    /**
    This function returns a string of the one-time password

    # Example

    ```rust
    use ootp::totp::{Totp, CreateOption};

    let secret = "A strong shared secrett";
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
            algorithm: self.algorithm,
        })
    }

    /**
    This function returns a string of the one-time password, valid a `period` from `time` seconds since the UNIX epoch

    # Example

    ```rust
    use ootp::totp::{Totp, CreateOption};

    let secret = "A strong shared secrett";
    let totp = Totp::secret(
        secret,
        CreateOption::Default
    );

    let otp = totp.make_time(59); // Generate a one-time password, valid a `DEFAULT_PERIOD from `59` seconds since the UNIX epoch
    println!("{}", otp); // Print the one-time password
    ```

    */
    pub fn make_time(&self, time: u64) -> String {
        self.hotp.make(MakeOption::Full {
            counter: time / self.period,
            digits: self.digits,
            algorithm: self.algorithm,
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
                algorithm: self.algorithm,
            },
        )
    }
}

#[cfg(test)]
mod tests {
    use super::{CreateOption, Totp};
    use crate::constants::{self, DEFAULT_DIGITS};

    #[test]
    fn it_works() {
        let secret = "A strong shared secret";
        let totp = Totp::secret(secret, CreateOption::Default);
        let code = totp.make();
        assert_eq!(code.len(), DEFAULT_DIGITS as usize);
    }

    /// Taken from [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238#appendix-B)
    #[test]
    fn make_test_correcteness() {
        let secret = "12345678901234567890";
        let totp = Totp::secret(secret, CreateOption::Digits(8));
        let code = totp.make_time(59);
        assert_eq!(code, "94287082");
        let code = totp.make_time(1111111109);
        assert_eq!(code, "07081804");
        let code = totp.make_time(1111111111);
        assert_eq!(code, "14050471");
        let code = totp.make_time(1234567890);
        assert_eq!(code, "89005924");
        let code = totp.make_time(2000000000);
        assert_eq!(code, "69279037");
        let code = totp.make_time(20000000000);
        assert_eq!(code, "65353130");
    }

    /// Taken from [RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238#appendix-B)
    /// Errata for [RFC 6238]](https://www.rfc-editor.org/errata_search.php?rfc=6238&rec_status=0)
    #[test]
    fn make_test_correcteness_sha256() {
        let secret = "12345678901234567890123456789012";
        let totp = Totp::secret(
            secret,
            CreateOption::Full {
                digits: 8,
                period: constants::DEFAULT_PERIOD,
                algorithm: &hmacsha::ShaTypes::Sha2_256,
            },
        );
        let code = totp.make_time(59);
        assert_eq!(code, "46119246");
        let code = totp.make_time(1111111109);
        assert_eq!(code, "68084774");
        let code = totp.make_time(1111111111);
        assert_eq!(code, "67062674");
        let code = totp.make_time(1234567890);
        assert_eq!(code, "91819424");
        let code = totp.make_time(2000000000);
        assert_eq!(code, "90698825");
        let code = totp.make_time(20000000000);
        assert_eq!(code, "77737706");
    }

    #[test]
    fn check_test() {
        let secret = "A strong shared secret";
        let totp = Totp::secret(secret, CreateOption::Default);
        let code = totp.make();
        assert!(totp.check(code.as_str(), None))
    }

    #[test]
    fn rapid_make_test() {
        let secret = "A strong shared secret";
        let totp = Totp::secret(secret, CreateOption::Default);
        let code1 = totp.make();
        let code2 = totp.make();
        assert!(totp.check(code1.as_str(), None));
        assert!(totp.check(code2.as_str(), None));
        assert_eq!(code1, code2);
    }
}
