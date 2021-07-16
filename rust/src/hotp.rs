use hmacsha1::hmac_sha1;

fn u64_to_8_length_u8_array(input: u64) -> [u8; 8] {
    let mut bytes = [0_u8; 8];
    for (i, item) in bytes.iter_mut().enumerate().take(7) {
        *item = (input >> (i * 8)) as u8;
    }
    bytes.reverse();
    bytes
}

pub struct HOTP {
    pub secret: String,
    pub counter: u64,
}

impl Clone for HOTP {
    fn clone(&self) -> Self {
        Self {
            secret: self.secret.clone(),
            counter: self.counter,
        }
    }
}

impl HOTP {
    pub fn new(secret: String, counter: u64) -> HOTP {
        HOTP { secret, counter }
    }

    pub fn make(&self, digits: u32) -> String {
        let counter_bytes = u64_to_8_length_u8_array(self.counter);
        let digest = hmac_sha1(self.secret.as_bytes(), &counter_bytes);
        let offset = digest[19] as usize & 0x0f;
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

    pub fn check(&mut self, otp: &str, window: u64) -> bool {
        self.counter -= window;
        let count = self.counter + window;
        loop {
            let code = self.make(otp.len() as u32);
            if code == otp {
                break true;
            } else if count < self.counter {
                break false;
            }

            self.counter += 1;
        }
    }
}
