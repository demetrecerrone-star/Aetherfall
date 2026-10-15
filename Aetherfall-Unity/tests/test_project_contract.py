"""Simple source and asset checks, not Unity runtime tests."""
import json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=(root/'Assets/Scripts/AetherfallFrontEnd.cs').read_text()
editor=(root/'Assets/Editor/AetherfallProjectSetup.cs').read_text()
intro=(root/'Assets/Scripts/AetherfallIntroSequence.cs').read_text()
for name in ['TitleLandscape', 'CastleGate', 'LoginPanel', 'IconMail', 'IconLock', 'IconEye', 'IconGoogle', 'Mote']:
    p = root/'Assets/Resources'/f'{name}.png'
    if not p.exists(): p=p.with_suffix('.jpg')
    assert p.exists(),p
    Image.open(p).verify()
assert 'field.placeholder = null' in source
assert 'InputField.ContentType.Password' in source
assert 'Google Login' in source
assert 'Play as Guest' in source
assert 'EnterGuestWorld' in source
assert 'SceneManager.LoadSceneAsync("StarterTown", LoadSceneMode.Single)' in source
assert 'Application.CanStreamedLevelBeLoaded("StarterTown")' in source
assert 'if (scene.name == "StarterTown") return;' in source
assert 'SceneManager.sceneLoaded += OnSceneLoaded;' in source
assert 'UnityEngine.UI' in source
assert 'Application.targetFrameRate = 60' in source
assert 'Screen.safeArea' in source
assert 'No credentials have been sent or saved' in source or 'no credentials have been sent or saved' in source
assert 'Aetherfall/Build Android Preview APK' in editor
assert 'com.demetrecerrone.aetherfall.unitydev' in editor
assert 'AetherfallLandscapePrebuild : IPreprocessBuildWithReport' in editor
assert 'AetherfallProjectSetup.ConfigureLandscape();' in editor
assert 'AetherfallMainBuildPreExport' in editor
assert 'AetherfallWorldBuilder.GenerateStarterTown();' in editor
assert 'new EditorBuildSettingsScene(TownScenePath, true)' in editor
assert 'new[] { ScenePath, TownScenePath }' in editor
assert 'AETHERFALL_GUEST_WORLD_READY' in editor
assert 'AetherfallProjectSetup.EnsureScene();' in editor
assert 'PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft' in editor
assert 'PlayerSettings.allowedAutorotateToPortrait = false' in editor
assert 'PlayerSettings.allowedAutorotateToPortraitUpsideDown = false' in editor
assert 'PlayerSettings.allowedAutorotateToLandscapeRight = false' in editor
assert 'Screen.orientation = ScreenOrientation.LandscapeLeft' in source
assert 'RuntimeInitializeLoadType.BeforeSplashScreen' in source
assert 'Screen.autorotateToPortrait = false' in source
# The UI alone cannot guarantee launch orientation. Unity's generated
# Android Activity manifest must be patched before Gradle packages the APK.
manifest_patch=(root/'Assets/Editor/AetherfallAndroidManifestOrientation.cs').read_text()
assert 'IPostGenerateGradleAndroidProject' in manifest_patch
assert 'OnPostGenerateGradleAndroidProject(string unityLibraryPath)' in manifest_patch
assert 'src", "main", "AndroidManifest.xml' in manifest_patch
assert 'screenOrientation' in manifest_patch
assert 'orientation.Value = "landscape"' in manifest_patch
assert 'UnityPlayer' in manifest_patch
assert 'AppUIGameActivity' in manifest_patch
assert 'Refusing to produce an APK' in manifest_patch
assert 'AETHERFALL_ORIENTATION_VERIFY' in manifest_patch
buildsettings=(root/'ProjectSettings/EditorBuildSettings.asset').read_text()
assert 'enabled: 1' in buildsettings
assert 'path: Assets/Scenes/AetherfallFrontEnd.unity' in buildsettings
assert (root/'Assets/Scenes/AetherfallFrontEnd.unity').is_file()
assert (root/'Assets/Scenes/AetherfallFrontEnd.unity.meta').is_file()
assert (root/'Assets/StreamingAssets').is_dir()
assert 'AetherfallIntro.mp4' in intro
assert 'SceneManager.GetActiveScene().name == "StarterTown"' in intro
assert (root/'Assets/Editor/AetherfallWorldBuilder.cs').is_file()
assert (root/'Assets/WorldBuilder/starter-town.json').is_file()
assert '"Town Guild Hall - Civic Government"' in (root/'Assets/Editor/AetherfallWorldBuilder.cs').read_text()
assert '"Player Spawn - Inside South Gate"' in (root/'Assets/Editor/AetherfallWorldBuilder.cs').read_text()
assert (root/'Assets/Scripts/AetherfallGuestExplorer.cs').is_file()
guest=(root/'Assets/Scripts/AetherfallGuestExplorer.cs').read_text()
assert 'SceneManager.sceneLoaded += OnSceneLoaded' in guest
assert 'CharacterController' in guest
assert 'Sprint' in guest
assert 'Guest Explorer' in guest
assert 'Screen.safeArea' in guest
assert 'VideoPlayer' in intro and 'StreamingAssets' in intro
assert 'FinishIntro' in intro and 'Skip Intro' in intro
manifest=json.loads((root/'Packages/manifest.json').read_text())
assert 'com.unity.modules.video' in manifest['dependencies']
for name in ['male.glb','female.glb']:
    assert (root/'Documentation'/name).stat().st_size > 10000
print('PASS - startup scene, Unity video intro source, title/login UI assets, Android source contract')
