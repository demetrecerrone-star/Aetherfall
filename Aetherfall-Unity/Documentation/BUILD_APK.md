# Aetherfall Unity — build an Android APK from your phone

The preferred build route is **Unity Build Automation**. The project ZIP is a Unity source project, not an APK.

## 1. Place the project on GitHub

Download the Aetherfall-Unity-Stage1-Build-Ready.zip file and visit:
https://github.com/demetrecerrone-star/Aetherfall/tree/unity-reboot

Select **Add file → Upload files** on the `unity-reboot` branch and select the ZIP (upload it as a ZIP, with no need to unzip it on your phone). Commit to `unity-reboot`, **not** `main`.

The GitHub workflow `.github/workflows/unity-reboot-import.yml` unpacks it under `Aetherfall-Unity/`, commits those files and runs project source checks. View progress under the repository's Actions tab. If the GitHub workflow is disabled or can't push, it must be allowed to run and have write access in the repository's Actions settings.

## 2. Create a cloud Android APK using Unity Build Automation

Sign into https://cloud.unity.com/ and select DevOps → Build Automation. Connect the Aetherfall GitHub repository. Choose:

- Git branch: `unity-reboot`
- Project subfolder: `Aetherfall-Unity`
- Unity editor version: `6000.3.26f1`
- Platform: Android
- Export: APK / development testing
- Application identifier: `com.demetrecerrone.aetherfall.unitydev`

Use a temporary development keystore only for initial test installs. Before ongoing APK updates or publishing, use a permanent keystore and store it securely in the Unity service. Run a build, read any compilation errors, and download the APK on your Android phone from the completed Unity build.

Unity may require creating a Unity Cloud project and configuring billing/build credits. Check the pricing on the Unity dashboard; do not enable billing without reviewing charges.

## 3. Alternative: GameCI GitHub Actions

The included `.github/workflows/android-preview.yml` is an optional GameCI runner that requires **valid and supported Unity CI licensing** in encrypted repository secrets. Do not rely on the legacy manual ALF/ULF flow for Unity Personal: current Unity documentation says manual activation doesn't support Personal. Unity's own Build Automation is usually more suitable when using only an Android phone.

## What this build contains

Title screen, a camera-like image-backed transition, login with editable fields, password eye toggle, Create Account UI, Google Login UI, and Settings placeholder. Actual Google sign-in and email/password authentication are not connected. The 3D town is not yet in the Unity reboot.

**Important:** A Unity Android APK has not yet been compiled here. Source validation is not a substitute for Unity Editor or Android device testing.
