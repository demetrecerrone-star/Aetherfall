import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
preset=json.loads((root/"Assets/WorldBuilder/starter-town.json").read_text())
code=(root/"Assets/Editor/AetherfallWorldBuilder.cs").read_text()
assert preset["seed"]==77421
assert preset["width"]>=245 and preset["depth"]>=225
assert 0<=preset["residentialHouses"]<=8
assert preset["foliageOuterRadius"] >= preset["width"]*.65
for name in ["Generate Starter Town", "EditorSceneManager.SaveScene",
             "Town Walls and South Gate", "South Gate West Tower",
             "Central Fountain Landmark", "Adventurers Guild",
             "The Hearth Inn", "Blacksmith and Forge", "Healing Shrine",
             "General Supply Shop", "Combat Training Yard",
             "Gate Market Loop Road", "Winding Guild Approach",
             "Residential Return Lane", "Market Shopfront Spur",
             "CurvedRoad", "RingRoad", "WallSegment", "wallOutline",
             "UnityEngine.Object.DestroyImmediate(collider)"]:
    assert name in code, name
assert "EditorBuildSettings.scenes =" not in code, "do not touch startup build configuration"
print("PASS: World Builder preset, layout landmarks and safe scene separation")
