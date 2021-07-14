import base32 from 'thirty-two';
import { TOTP } from '../../typescript/src/totp';

export function createOtpAuthUri(secret: string | Buffer, options: {
    issuer: string;
    account?: string;
    digits?: number;
    period?: number;
    type: 'hotp' | 'totp';
}): string {
    const encodedIssuer = encodeURIComponent(options.issuer);
    const encodedAccount = encodeURIComponent(options.account || '');
    const digits = options.digits || 6;
    const period = options.period || 30;
    const type = options.type;
    const encodedSceret = base32.encode(secret).toString("utf-8").replace(/=/g, '');

    return `otpauth://${type}/${encodedIssuer}:${encodedAccount}?secret=${encodedSceret}&counter=${period}&digits=${digits}&issuer=${encodedIssuer}`;
}

const sceret = base32.decode('MU2TSNRZG5TGKMBYGAZDCMJTMM3GIMJVMZRTINDFGI3WGZRVMQ4Q');
const otp = '344592';

const totp = new TOTP({
    secret: sceret,
    digits: 6,
    period: 30,
});

// TOTP debug info,
console.log(`
SHA1:
    otp: ${totp.make()}
    uri: ${createOtpAuthUri(sceret, { period: 30, type: 'totp', issuer: 'Test', account: "Seven" })}
    valid: ${totp.check(otp)}
`);

