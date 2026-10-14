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
assert 'Continue as Guest' not in source
assert 'UnityEngine.UI' in source
assert 'Application.targetFrameRate = 60' in source
assert 'Screen.safeArea' in source
assert 'No credentials have been sent or saved' in source or 'no credentials have been sent or saved' in source
assert 'Aetherfall/Build Android Preview APK' in editor
assert 'com.demetrecerrone.aetherfall.unitydev' in editor
assert 'AetherfallLandscapePrebuild : IPreprocessBuildWithReport' in editor
assert 'AetherfallProjectSetup.ConfigureLandscape();' in editor
assert 'PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft' in editor
assert 'PlayerSettings.allowedAutorotateToPortrait = false' in editor
assert 'PlayerSettings.allowedAutorotateToPortraitUpsideDown = false' in editor
assert 'PlayerSettings.allowedAutorotateToLandscapeRight = false' in editor
assert 'Screen.orientation = ScreenOrientation.LandscapeLeft' in source
assert 'RuntimeInitializeLoadType.BeforeSplashScreen' in source
assert 'Screen.autorotateToPortrait = false' in source
buildsettings=(root/'ProjectSettings/EditorBuildSettings.asset').read_text()
assert 'enabled: 1' in buildsettings
assert 'path: Assets/Scenes/AetherfallFrontEnd.unity' in buildsettings
assert (root/'Assets/Scenes/AetherfallFrontEnd.unity').is_file()
assert (root/'Assets/Scenes/AetherfallFrontEnd.unity.meta').is_file()
assert (root/'Assets/StreamingAssets').is_dir()
assert 'AetherfallIntro.mp4' in intro
assert 'VideoPlayer' in intro and 'StreamingAssets' in intro
assert 'FinishIntro' in intro and 'Skip Intro' in intro
manifest=json.loads((root/'Packages/manifest.json').read_text())
assert 'com.unity.modules.video' in manifest['dependencies']
for name in ['male.glb','female.glb']:
    assert (root/'Documentation'/name).stat().st_size > 10000
print('PASS - startup scene, Unity video intro source, title/login UI assets, Android source contract')
