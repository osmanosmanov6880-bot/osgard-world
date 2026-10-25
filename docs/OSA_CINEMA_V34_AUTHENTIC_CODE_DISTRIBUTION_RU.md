# OSA CINEMA V34: independent publisher authenticity, local verification, no film release

## Purpose

V32.1 and V33 SHA256 inventories detect modifications to the program after the archive
has been received; they do **not** authenticate who made the archive. V34 adds an
offline Ed25519 *verification* tool with a strictly pinned publisher public key.
This module verifies code distribution only, never video rights or film publication.

## Mandatory inputs

1. `OSA_CINEMA_...zip` - the owner code archive, not private film assets.
2. `OSA_CINEMA_...sig.json` - detached signature received from a publisher.
3. `publisher-public.pem` - Ed25519 public key supplied separately (NOT a private key).
4. The 64-hex SHA256 fingerprint of this public key's **SPKI DER** bytes, obtained
   and compared independently (trusted owner channel). Never accept a pin copied
   from the same ZIP, signature JSON, or its README as independent trust.

No publisher private key, digital signature, or owner identity is fabricated or
bundled in this engineering package. V34 therefore cannot claim that this
specific archive has been signed by an approved publisher.

## Verification command (Node.js 22+)

```bash
node scripts/osa-cinema-v34-detached-signature.mjs verify \
  --archive /absolute/path/OSA_CINEMA_CODE.zip \
  --signature /absolute/path/OSA_CINEMA_CODE.sig.json \
  --public-key /absolute/path/publisher-public.pem \
  --trusted-key-sha256 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

Replace the example paths and SHA fingerprint with real values. On Windows enter
the entire command on one line with absolute Windows paths. The above example
fingerprint is intentionally NOT trusted and is NOT a valid authority claim.
Failure returns exit code 1. Do not suppress it. After successful signature
verification, still verify the unpacked SHA256 inventory with
`scripts/osa-cinema-v32-package-integrity.mjs` before running code.

## Signature document format for an actual authorized publisher

```json
{
  "schemaVersion": 1,
  "algorithm": "Ed25519",
  "purpose": "OSA_CINEMA_CODE_ARCHIVE_ONLY",
  "archiveName": "OSA_CINEMA_CODE.zip",
  "sha256": "actual-sha256-of-archive-replace-this",
  "signature": "actual-Ed25519-signature-base64-replace-this",
  "publicationAuthorized": false,
  "rightsCleared": false,
  "paidCheckoutEnabled": false,
  "releaseDecision": "NO_GO"
}
```

The publisher signs these exact UTF-8 message bytes with Ed25519:
`OSA-CINEMA-CODE-ARCHIVE-V1\n<archiveName>\n<sha256>\n`.
The verification key fingerprint is SHA256 over Ed25519 public key **SPKI DER**.
Neither the signature JSON nor the signer is trusted without the independent pin.

## V34 negative security regressions

- No independent publisher fingerprint -> BLOCK.
- Public key differs from independent fingerprint -> BLOCK.
- ZIP has changed after signing -> BLOCK.
- Wrong private signing key or invalid Ed25519 signature -> BLOCK.
- Symbolic-link paths, nonordinary files, unreasonable sizes -> BLOCK.
- Malformed metadata, unrecognized fields, forged GO/rights/payment -> BLOCK.
- Wrong ZIP basename or unexpected archive format -> BLOCK.

The tool checks content integrity and publisher-key continuity. It is not a full
software sandbox, does not perform independent legal identity verification, and
does not close all filesystem race windows. Use it on the owner's local machine
with independently obtained signed release data and a reviewed publisher key.

## Release decision: mandatory NO-GO

None of these V34 verification successes permits public film distribution,
paid checkout, subscriptions or unlocking films. Still required: approved 4
real MP4 files and 4 matching WebVTT captions; human RU/EN QA; verified rights
to footage/music/voices/fonts/images; independently authenticated signers;
production HTTPS, monitoring, physical-device checks and rollback; written
publisher signoff bound to the exact film master hashes. Never present
synthetic test videos or test Ed25519 keys as real source evidence.

## GitHub handoff

The GitHub PR should include only this verifier, its tests, this document and
its workflow. The standalone V32/V33 owner packages and historical V18 evidence
are separate; do not overwrite existing GitHub V18 QA or V20 release policy.
A successful GitHub Actions run tests code only and does not authorize premiere.
