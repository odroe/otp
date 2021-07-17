use crate::constants::{ DEFAULT_BREADTH, DEFAULT_COUNTER, DEFAULT_DIGITS };
use hmacsha1::hmac_sha1;

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

pub enum HotpMakeOption {
    Default,
    Counter(u64),
    Digits(u32),
    Full {
        counter: u64,
        digits: u32,
    },
}

pub enum HotpCheckOption {
    Default,
    Counter(u64),
    Breadth(u64),
    Full {
        counter: u64,
        breadth: u64,
    },
}

pub struct Hotp(pub String);

impl Hotp {
    pub fn make(&self, options: HotpMakeOption) -> String {
        match options {
            HotpMakeOption::Default => make_opt(self.0.as_bytes(), DEFAULT_DIGITS, DEFAULT_COUNTER),
            HotpMakeOption::Counter(counter) => make_opt(self.0.as_bytes(), DEFAULT_DIGITS, counter),
            HotpMakeOption::Digits(digits) => make_opt(self.0.as_bytes(), digits, DEFAULT_COUNTER),
            HotpMakeOption::Full {
                counter,
                digits,
            } => make_opt(self.0.as_bytes(), digits, counter),
        }
    }
    
    pub fn check(&self, otp: &str, options: HotpCheckOption) -> bool {
        let (counter, breadth) = match options {
            HotpCheckOption::Default => (DEFAULT_COUNTER, DEFAULT_BREADTH),
            HotpCheckOption::Counter(counter) => (counter, DEFAULT_BREADTH),
            HotpCheckOption::Breadth(breadth) => (DEFAULT_COUNTER, breadth),
            HotpCheckOption::Full {
                counter,
                breadth,
            } => (counter, breadth),
        };
        for i in (counter - breadth)..=(counter + breadth) {
            let code = self.make(HotpMakeOption::Full {
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
    use super::{Hotp, HotpMakeOption};

    #[test]
    fn make() {
        let hotp = Hotp(String::from("test"));
        let code1 = hotp.make(HotpMakeOption::Default);
        let code2 = hotp.make(HotpMakeOption::Default);

        assert_eq!(code1, code2);
    }
}
