use base32;
use ootp::TOTP;

fn totp_factory() -> TOTP {
    let encoded_secret = "MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q"; // The secret key is a base32 encoded string

    let secret_vec =
        base32::decode(base32::Alphabet::RFC4648 { padding: false }, encoded_secret).unwrap();
    let secret = String::from_utf8(secret_vec).unwrap();

    let period = 30; // 30 seconds
    let digits = 6; // 6 digits

    TOTP::new(secret, digits, period)
}

fn main() {
    let otp_auth_uri = "otpauth://totp/{issuer}:{account}?secret={secret}&issuer={issuer}&period={period}&digits={digits}"
        .replace("{issuer}", "OOTP")
        .replace("{account}", "Tester")
        .replace("{secret}", &totp_factory().hotp.secret)
        .replace("{period}", &totp_factory().period.to_string())
        .replace("{digits}", &totp_factory().digits.to_string());

    let top = "790749";

    println!("valid: {:?}", totp_factory().check(top, 0));
    println!("otp: {:?}", totp_factory().make());
    println!("uri: {:?}", otp_auth_uri);
}
