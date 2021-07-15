use std::time::SystemTime;
use hmacsha1::hmac_sha1;

fn u64_to_8_length_u8_array(input: u64) -> [u8; 8] {
    let mut bytes = [0u8; 8];
    for i in 0..7 {
        bytes[i] = (input >> (i * 8)) as u8;
    }
    bytes.reverse();
    bytes
}

pub struct HOTP {
    secret: String,
}

impl HOTP {
    pub fn new(secret: String) -> HOTP {
        HOTP { secret }
    }

    pub fn make(self, digits: u8, counter: u64) -> String {
        let counter_bytes = u64_to_8_length_u8_array(counter);
        let digest = hmac_sha1(self.secret.as_bytes(), &counter_bytes);
        let offset = digest[19] as usize & 0xf;
        let value = ((digest[offset] as u32) & 0x7f) << 24 |
            ((digest[offset + 1] as u32) & 0xff) << 16 |
            ((digest[offset + 2] as u32) & 0xff) << 8 |
            (digest[offset + 3] as u32) & 0xff;
        let code = value % 10u32.pow(digits as u32);
        code.to_string()
    }
}

fn main() {
    let secret = String::from("e59697fe0802113c6d15fc44e27cf5d9");
    let hotp = HOTP::new(secret);

    // 当前时间戳
    let timestamp = SystemTime::now().duration_since(SystemTime::UNIX_EPOCH)
        .unwrap()
        .as_secs() / 30;

    let result = hotp.make(6, timestamp);

    println!("{}", timestamp);
    println!("{}", result);
}
