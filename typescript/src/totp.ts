import { HTOP } from "./htop";

export interface TOTPOptions {
    secret: Buffer | HTOP;
    digits?: number;
    period?: number;
}

export class TOTP implements Required<Pick<TOTPOptions, "digits" | "period">> {
    public readonly hotp: HTOP;
    public readonly digits: number;
    public readonly period: number;

    public constructor(options: TOTPOptions) {
        this.hotp = options.secret instanceof HTOP ? options.secret : new HTOP(options.secret);
        this.digits = options.digits || 6;
        this.period = options.period || 30;
    }

    protected createCounter(): number {
        return Math.floor(Date.now() / this.period / 1000);
    }

    public make(): string {
        return this.hotp.make(this.digits, this.createCounter());
    }

    public check(otp: string, margin?: number): boolean {
        return this.hotp.check(otp, {
            margin,
            counter: this.createCounter(),
        });
    }
}