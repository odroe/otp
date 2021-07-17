use crate::{
    constants::{DEFAULT_DIGITS, DEFAULT_PERIOD},
    hotp::{Hotp, HotpCheckOption, HotpMakeOption},
};
use std::time::SystemTime;

fn create_counter(period: u64) -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        / period
}

pub struct Totp {
    pub hotp: Hotp,
    pub digits: u32,
    pub period: u64,
}

pub enum TotpWithSecretCreateOption {
    Default,
    Digits(u32),
    Period(u64),
    Full { digits: u32, period: u64 },
}

impl Totp {
    pub fn secret(secret: String, option: TotpWithSecretCreateOption) -> Totp {
        let hotp = Hotp(secret);
        let (digits, period) = match option {
            TotpWithSecretCreateOption::Default => (DEFAULT_DIGITS, DEFAULT_PERIOD),
            TotpWithSecretCreateOption::Digits(digits) => (digits, DEFAULT_PERIOD),
            TotpWithSecretCreateOption::Period(period) => (DEFAULT_DIGITS, period),
            TotpWithSecretCreateOption::Full { digits, period } => (digits, period),
        };
        Totp {
            hotp,
            digits,
            period,
        }
    }

    pub fn make(&self) -> String {
        self.hotp.make(HotpMakeOption::Full {
            counter: create_counter(self.period),
            digits: self.digits,
        })
    }

    pub fn check(&self, otp: &str, breadth: Option<u64>) -> bool {
        self.hotp.check(
            otp,
            HotpCheckOption::Full {
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
        let secret = String::from("test");
        let totp = super::Totp::secret(secret, super::TotpWithSecretCreateOption::Default);

        let otp = totp.make();

        assert_eq!(otp.len(), super::DEFAULT_DIGITS as usize);
    }
}
