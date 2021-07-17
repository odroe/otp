import crypto from 'crypto';

type AlgorithmType = 'sha1';
const algorithm: AlgorithmType = 'sha1';

// The HTOP class.
export class HTOP {
    public static readonly algorithm: AlgorithmType = algorithm;

    // Constructor.
    public constructor(public readonly secret: Buffer) {}

    // Int to bytes, reurn a number array.
    protected int2bytes(input: number): Buffer {
        const bytes = [];
        for (let i = 0; i < 8; i++) {
            bytes.push(input & 0xff);
            input >>= 8;
        }

        return Buffer.from(bytes.reverse());
    }

    // hex to bytes, return a number array.
    protected hex2bytes(input: string): Buffer {
        const bytes = [];
        for (let i = 0; i < input.length; i += 2) {
            bytes.push(parseInt(input.substr(i, 2), 16));
        }
        return Buffer.from(bytes);
    }

    // Make a OTP.
    public make(digits: number = 6, counter: number = 0): string {
        const counterBytes = this.int2bytes(counter);
        const hmac = crypto.createHmac(algorithm, this.secret);
        const digestHex = hmac.update(counterBytes).digest("hex");
        const digestBytes = this.hex2bytes(digestHex);
        const offset = digestBytes[19] & 0xf;
        const value = (digestBytes[offset] & 0x7f) << 24 |
            (digestBytes[offset + 1] & 0xff) << 16 |
            (digestBytes[offset + 2] & 0xff) << 8 |
            (digestBytes[offset + 3] & 0xff);

        const result = String(value % Math.pow(10, digits));

        return new Array(digits - result.length + 1).join('0') + result;
    }

    // Check a OPT.
    public check(otp: string, options: {
        breadth?: number;
        counter?: number;
    }): boolean {
        const counter = options && options.counter ? options.counter : 0;
        const breadth = options && options.breadth ? options.breadth : 0;

        for (let i = counter - breadth; i <= counter + breadth; ++i) {
            if (otp === this.make(otp.length, i)) {
                return true;
            }
        }

        return false;
    }
}       
    