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

pub struct Totp<'a> {
    pub hotp: Hotp<'a>,
    pub digits: u32,
    pub period: u64,
}

pub enum CreateOption {
    Default,
    Digits(u32),
    Period(u64),
    Full { digits: u32, period: u64 },
}

impl Totp<'_> {
    pub fn secret(secret: &'static str, option: CreateOption) -> Totp<'static> {
        let hotp = Hotp(secret);
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
    #[test]
    fn it_works() {
        let secret = "test";
        let totp = super::Totp::secret(secret, super::CreateOption::Default);

        let otp = totp.make();

        assert_eq!(otp.len(), super::DEFAULT_DIGITS as usize);
    }
}
