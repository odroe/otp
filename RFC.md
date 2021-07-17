Public API RFC (Request for Comments) of OOTP (Open One-time Password).

## Alogrithm implementation

 * [RFC 4226](https://tools.ietf.org/html/rfc4226)
 * [RFC 6238](https://tools.ietf.org/html/rfc6238)

## Interface methods

 * `make` - Generate a one-time password.
 * `check` - Check if a one-time password is valid.

## HOTP

The HOTP is a HMAC-based one-time password algorithm.

`constructor` parameters:
    - `secret` - The secret key.

### make

 * Parameters:
   * `counter` - The counter, a non-negative integer, defaults to 0.
   * `digits` - The number of digits of the one-time password, a non-negative integer, defaults to 6.
   * `breadth` - The degree of password looseness to check, a non-negative integer, defaults to 0.
 * Returns: a string of the one-time password.

### check

 * Parameters:
   * `otp` - The one-time password.
   * `counter` - The counter, a non-negative integer, defaults to 0.
   * `breadth` - The degree of password looseness to check, a non-negative integer, defaults to 0.
 * Returns: a boolean indicating if the one-time password is valid.

## TOTP

 * Parameters:
   * `hotp` - The HOTP instance.
   * `digits` - The number of digits of the one-time password, is `6` by default and optional.
   * `period` - The period of the one-time password, is `30` by default and optional.

### make

 * Parameters: No parameters.
 * Returns: a string of the one-time password.

### check

 * Parameters:
   * `otp` - The one-time password.
   * `breadth` - The degree of password looseness to check.
 * Returns: a boolean indicating if the one-time password is valid.
