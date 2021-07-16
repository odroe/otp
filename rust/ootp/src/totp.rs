use crate::hotp::HOTP;
use std::time::SystemTime;

fn create_counter(period: u64) -> u64 {
    SystemTime::now().duration_since(SystemTime::UNIX_EPOCH).unwrap().as_secs() / period
}

pub struct TOTP {
    pub hotp: HOTP,
    pub digits: u32,
    pub period: u64,
}

impl TOTP {
    pub fn new(secret: String, digits: u32, period: u64) -> TOTP {
        TOTP {
            hotp: HOTP::new(secret, 0),
            digits,
            period,
        }
    }

    pub fn make(&mut self) -> String {
        self.hotp.counter = create_counter(self.period);
        self.hotp.make(self.digits)
    }

    pub fn check(&mut self, otp: &str, window: u64) -> bool {
        self.hotp.counter = create_counter(self.period);
        self.hotp.check(otp, window)
    }
}
