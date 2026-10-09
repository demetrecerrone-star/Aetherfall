# Android signing plan — v0.2+

## Current state

Aetherfall uses package ID `com.demetrecerrone.aetherfall`. Version codes increment per APK release. The original v0.1 debug signing key was created ephemerally inside GitHub Actions, then discarded. It is impossible to install a new APK signed with a different certificate *over* that build: uninstall v0.1 first (the v0.1 prototype has no persistent account data).

## Long-term signed debug builds

The CI workflow can use a repository-scoped, stable signing key if all 3 secrets are configured:

| Secret | Content |
|---|---|
| `AETHERFALL_KEYSTORE_B64` | One-line base64 encoding of the entire private keystore (.jks/.keystore). |
| `AETHERFALL_KEY_ALIAS` | Keystore key alias, e.g. `aetherfall`. |
| `AETHERFALL_KEY_PASSWORD` | Password for the keystore key (use the same key and store password for Godot debug exports). |

**Do not place any keystore or password in Git commits, issues, pull requests, screenshots or chat.** Add values under the GitHub repository's Settings → Secrets and variables → Actions → New repository secret. Save an encrypted offline backup of the keystore *and* the password in a password manager.

To generate a fresh key from a trusted local computer with Java installed (replace the example password and store it securely):

```bash
keytool -genkeypair -v \
  -keystore aetherfall-upload.jks -storetype PKCS12 \
  -alias aetherfall -keyalg RSA -keysize 3072 -validity 10000 \
  -storepass YOUR_STRONG_PASSWORD -keypass YOUR_STRONG_PASSWORD \
  -dname "CN=Aetherfall Developer, O=Aetherfall"
```

To encode, use a local terminal and do not share the output publicly:

```bash
base64 -w 0 aetherfall-upload.jks
```

On macOS use `base64 -i aetherfall-upload.jks | tr -d '\\n'`.

Once the three secrets are in place, GitHub Actions will sign every debug build with that keystore. The first switch from the original v0.1 ephemeral certificate requires **one reinstall**; future builds signed with the stable certificate can update in place as long as version codes rise.

## Production release signing

Use a separate, safely backed-up release/upload key for Play Store distribution. Play App Signing uses its own signing process; do not assume debug keys can be reused for a production AAB without configuration.

## Security

The workflow does not print private key bytes. The temporary fallback key is for quick prototype testing **only**, not a security or update plan. Android update compatibility is determined by **both** the package ID and signing identity; raising `version/code` without retaining the signing identity will not work.
