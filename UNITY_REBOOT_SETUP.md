# Aetherfall Unity Reboot

This Unity development branch is separate from the established Godot code on main. Do not merge until the Unity app has been tested.

## Android build from a phone

1. Download the Aetherfall-Unity-Stage1-Build-Ready.zip project archive from the ChatGPT conversation.
2. On this branch (unity-reboot), choose Add file > Upload files on GitHub, select that ZIP, and commit.
3. The Unity bootstrap workflow will extract the Unity source into the Aetherfall-Unity folder. It can then be used in Unity's Build Automation.

In Unity Cloud Dashboard > DevOps > Build Automation, link this repository, choose branch unity-reboot, select project folder Aetherfall-Unity, select Unity 6000.3.26f1 and Android APK target. Unity handles editor licensing in its cloud environment. The user must authorize their own Unity account and any GitHub connection.

Optional alternative: GameCI GitHub Actions needs a supported Unity CI license configured as secrets. Unity Personal does not support the old manual activation method.

The title and login use image-backed artwork and real UI controls, not yet actual 3D castle geometry. Google sign-in and password authentication are not connected.
