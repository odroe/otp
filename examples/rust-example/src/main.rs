use base32;

use ootp::constants::*;
use ootp::totp::{CreateOption, Totp};

// fn totp_factory() -> TOTP {
//     let encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q"; // The secret key is a base32 encoded string

//     let secret_vec =
//         base32::decode(base32::Alphabet::RFC4648 { padding: false }, encoded_secret).unwrap();
//     let secret = String::from_utf8(secret_vec).unwrap();

//     let period = 30; // 30 seconds
//     let digits = 6; // 6 digits

//     TOTP::new(secret, digits, period)
// }

fn main() {
    let encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q"; // The secret key is a base32 encoded string
    let secret_vec =
        base32::decode(base32::Alphabet::RFC4648 { padding: false }, encoded_secret).unwrap();
    let secret = String::from_utf8(secret_vec).unwrap();
    let totp = Totp::secret(&secret, CreateOption::Default);

    let otp_auth_uri = "otpauth://totp/{issuer}:{account}?secret={secret}&issuer={issuer}&period={period}&digits={digits}"
        .replace("{issuer}", "OOTP")
        .replace("{account}", "Tester")
        .replace("{secret}", encoded_secret)
        .replace("{period}", &format!("{}", DEFAULT_PERIOD))
        .replace("{digits}", &format!("{}", DEFAULT_DIGITS));

    let top = "790749";

    println!("valid: {:?}", totp.check(top, None));
    println!("otp: {:?}", totp.make());
    println!("uri: {:?}", otp_auth_uri);
}
