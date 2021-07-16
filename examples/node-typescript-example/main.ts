import base32 from 'thirty-two';
import { TOTP } from 'ootp';

const sceret = base32.decode('MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q'); // The secret key is a base32 encoded string

const totp = new TOTP({
    secret: sceret,
    digits: 6,
    period: 30,
});

export function createOtpAuthUri(secret: string | Buffer, options: {
    issuer: string;
    account?: string;
    digits?: number;
    period?: number;
}): string {
    const encodedIssuer = encodeURIComponent(options.issuer);
    const encodedAccount = encodeURIComponent(options.account || '');
    const digits = totp.digits;
    const period = totp.period;
    const encodedSceret = base32.encode(secret).toString("utf-8").replace(/=/g, '');

    return `otpauth://totp/${encodedIssuer}:${encodedAccount}?secret=${encodedSceret}&issuer=${encodedIssuer}&period=${period}&digits=${digits}`;
}


const otp = '405436';

// TOTP debug info,
console.log(`
SHA1:
    otp: ${totp.make()}
    uri: ${createOtpAuthUri(sceret, { issuer: 'OOTP', account: "Tester" })}
    valid: ${totp.check(otp)}
`);

