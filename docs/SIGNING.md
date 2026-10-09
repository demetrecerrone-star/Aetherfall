# Android signing plan — v0.2+

## Current state

**v0.3.1 release gate:** Android APK builds now refuse to publish if the persistent Aetherfall signing secrets are absent or invalid. Temporary debug signing is permitted only for the separate, disposable x86_64 emulator QA APK; it is never an installable release build.

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

Once the three secrets are in place, GitHub Actions validates the keystore and alias, signs each installable debug build with that key, and compares the exported APK's certificate SHA-256 against the keystore before publishing it. A green emulator QA result alone does not prove the release APK is signed correctly. The first switch from the original v0.1 ephemeral certificate requires **one reinstall**; future builds signed with the stable certificate can update in place as long as version codes rise.

## Production release signing

Use a separate, safely backed-up release/upload key for Play Store distribution. Play App Signing uses its own signing process; do not assume debug keys can be reused for a production AAB without configuration.

## Security

The workflow does not print private key bytes. The temporary fallback key previously used for prototype APKs is no longer permitted in the release build. GitHub Actions errors instead of publishing an update with a different signing identity. Android update compatibility is determined by **both** the package ID and signing identity; raising `version/code` without retaining the signing identity will not work.
