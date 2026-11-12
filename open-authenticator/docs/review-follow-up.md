# PR 211 review follow-up

## Verified findings

The review's ten findings were checked against the current implementation.

| Finding | Disposition |
| --- | --- |
| Android backup/device-transfer policy | Owner explicitly chose not to prohibit system backup or device transfer. Existing policy remains; plaintext SQLite and retained Hive seeds may be included. This finding is acknowledged, not silently represented as fixed. |
| Explicit label `Acme:Acme` collapses to issuer-only | Preserve the explicit account name when a colon is present; existing stored keys are not rewritten. |
| Empty URI label with nonempty issuer accepted | Reject an empty label before issuer fallback. |
| Impossible Base32 lengths silently truncated | Reject unpadded lengths modulo eight of 1, 3, or 6. Existing records are not deleted or rewritten; malformed entries remain visible with an error. |
| Add-account accessibility label | Add an action-specific semantic label. |
| Unrelated barcode closes scanner | Ignore non-QR detections before completing the scan. |
| Clipboard completion uses disposed context | Check mounted after the asynchronous write. |
| Copy confirmation regenerates a different code | Capture once and reuse the clipboard value in the confirmation. |
| Delete-account accessibility label | Add an action-specific semantic label. |
| Help link platform exception escapes | Treat PlatformException as a failed launch and retain the error/copy-URL fallback. |

## HOTP/TOTP dependency assessment

Do not directly replace OOTP 0.1.1 with the currently published HOTP/TOTP 0.1.0
packages. HOTP passes `algorithm.repeat(secret)` to HMAC, repeating or truncating
the secret to the digest length rather than using the original secret. For SHA1
this changes every key whose length is not 20 bytes. For the public synthetic
Base32 key `JBSWY3DPEHPK3PXP`, counter 1 and six digits, standard HMAC and the old
OOTP return `996554`, while the current HOTP implementation returns `503347`.
The RFC SHA1 fixture alone does not detect this because its key is exactly
20 bytes long.

TOTP also defaults to SHA256/eight digits; an eventual adapter must explicitly
preserve SHA1, stored digits/period and case-normalized Base32 decoding. Fixing
and publishing the core packages needs a separate approved scope with RFC
4226/6238 and variable-length-secret regressions. This app iteration keeps OOTP;
no existing secrets or package sources are changed by this assessment.

## Regression validation

The combined parser and UI follow-up passes `flutter analyze` and all **61**
Flutter tests (35 prior tests, 20 parser regressions, 6 UI regressions). The UI
checks include delayed clipboard completion after unmount or account replacement,
failed/throwing external URL launch, accessible action labels, and mixed barcode
captures. No live credentials are used.

The final combined source also passes iOS unsigned release, Android default
ARM64 release, and full Android native lint (0 errors, 7 existing warnings).
No build tasks were excluded and no phone app was replaced during this review.
