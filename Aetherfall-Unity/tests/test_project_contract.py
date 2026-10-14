"""Simple source and asset checks, not Unity runtime tests."""
import json
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=(root/'Assets/Scripts/AetherfallFrontEnd.cs').read_text()
editor=(root/'Assets/Editor/AetherfallProjectSetup.cs').read_text()
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
json.loads((root/'Packages/manifest.json').read_text())
for name in ['male.glb','female.glb']:
    assert (root/'Documentation'/name).stat().st_size > 10000
print('PASS — assets, controls, inputs, secure placeholders, Android editor commands and model references are present')
