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

pub enum MakeOption {
    Default,
    Counter(u64),
    Digits(u32),
    Full { counter: u64, digits: u32 },
}

pub enum CheckOption {
    Default,
    Counter(u64),
    Breadth(u64),
    Full { counter: u64, breadth: u64 },
}
/// The HOTP is a HMAC-based one-time password algorithm.
pub struct Hotp<'a>(pub &'a str);

impl Hotp<'_> {
    /// This function returns a string of the one-time password
    ///
    /// # Example #1
    ///
    /// ```
    /// use ootp::{Hotp, MakeOption};
    ///
    /// let hotp = Hotp("test");
    /// let code = hotp.make(MakeOption::Default);
    /// ```
    ///
    /// # Example #2
    ///
    /// ```
    /// use ootp::{Hotp, MakeOption};
    /// let hotp = Hotp("test");
    /// let code = hotp.make(MakeOption::Default);
    /// ```
    pub fn make(&self, options: MakeOption) -> String {
        match options {
            MakeOption::Default => make_opt(self.0.as_bytes(), DEFAULT_DIGITS, DEFAULT_COUNTER),
            MakeOption::Counter(counter) => make_opt(self.0.as_bytes(), DEFAULT_DIGITS, counter),
            MakeOption::Digits(digits) => make_opt(self.0.as_bytes(), digits, DEFAULT_COUNTER),
            MakeOption::Full { counter, digits } => make_opt(self.0.as_bytes(), digits, counter),
        }
    }
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
    use super::{Hotp, MakeOption};

    #[test]
    fn make() {
        let hotp = Hotp("test");
        let code1 = hotp.make(MakeOption::Default);
        let code2 = hotp.make(MakeOption::Default);

        assert_eq!(code1, code2);
    }
}
