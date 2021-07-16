use crate::hotp::HOTP;
use std::time::SystemTime;

fn create_counter(period: u64) -> u64 {
    SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs()
        / period
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

#[cfg(test)]
mod tests {
    #[test]
    fn it_works() {
        let encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q"; // The secret key is a base32 encoded string

        let secret_vec =
            base32::decode(base32::Alphabet::RFC4648 { padding: false }, encoded_secret).unwrap();
        let secret = String::from_utf8(secret_vec).unwrap();

        let period = 30; // 30 seconds
        let digits = 6; // 6 digits

        let mut totp = crate::totp::TOTP::new(secret, digits, period);

        assert_eq!(totp.make().len(), digits as usize);
    }

    #[test]
    fn token_is_the_same_when_called_twice_quickly() {
        let encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q"; // The secret key is a base32 encoded string

        let secret_vec =
            base32::decode(base32::Alphabet::RFC4648 { padding: false }, encoded_secret).unwrap();
        let secret = String::from_utf8(secret_vec).unwrap();

        let period = 30; // 30 seconds
        let digits = 6; // 6 digits

        let mut totp1 = crate::totp::TOTP::new(secret.clone(), digits, period);
        let mut totp2 = crate::totp::TOTP::new(secret, digits, period);
        assert_eq!(totp1.make(), totp2.make());
    }
}
