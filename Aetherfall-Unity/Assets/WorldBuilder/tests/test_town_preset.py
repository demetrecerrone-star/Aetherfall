import json
from pathlib import Path
root=Path(__file__).resolve().parents[3]
preset=json.loads((root/"Assets/WorldBuilder/starter-town.json").read_text())
code=(root/"Assets/Editor/AetherfallWorldBuilder.cs").read_text()
assert preset["seed"]==77421
assert preset["guildHillHeight"] == 6
assert preset["width"]>=245 and preset["depth"]>=225
assert 0<=preset["residentialHouses"]<=8
assert preset["foliageOuterRadius"] >= preset["width"]*.65
for name in ["Generate Starter Town", "EditorSceneManager.SaveScene",
             "Town Walls and South Gate", "South Gate West Tower",
             "Central Fountain Landmark", "Town Guild Hall - Civic Government", "GuildHallDetails",
             "Guild Blue Banner", "Civic Stone Entry Step", "Roof Ridge Cap",
             "The Hearth Inn", "Blacksmith and Forge", "Healing Shrine",
             "General Supply Shop", "Combat Training Yard",
             "Gate Market Loop Road", "Winding Guild Approach",
             "Residential Return Lane", "Market Shopfront Spur",
             "CurvedRoad", "RingRoad", "WallSegment", "wallOutline",
             "BuildLandscapeMesh", "GroundHeight",
             "Quest and Contract Board", "Public Notices and Town Orders",
             "New Adventurer Registration",
             "UnityEngine.Object.DestroyImmediate(collider)"]:
    assert name in code, name
# Preview pipeline is EDITOR-ONLY; renders genuine Unity camera output, not a
# planning image. Successful source checks still do not prove Unity compilation.
preview = (root/"Assets/Editor/AetherfallTownPreviewCapture.cs").read_text()
for feature in [
    "GenerateAndCapture", "CaptureCurrentTown", "RenderTexture.GetTemporary",
    "camera.Render()", "EncodeToPNG()", "SystemInfo.graphicsDeviceType",
    "01-overhead-real-unity.png", "02-south-gate-market.png",
    "03-winding-road-to-guild.png", "04-guild-town-hall.png",
    "05-view-from-guild-hill.png", "Assets/Scenes/StarterTown.unity",
]:
    assert feature in preview, f"Missing preview feature: {feature}"
for landmark in [
    "Player Spawn - Inside South Gate",
    "Town Market Interaction Center",
    "Guild Registration Arrival",
    "Starter Field Exit - Beyond Gate",
]:
    assert landmark in code, landmark
assert "Application.dataPath" in code
assert "#if UNITY_EDITOR" in preview
assert "EditorBuildSettings.scenes =" not in preview
assert "EditorBuildSettings.scenes =" not in code, "do not touch startup build configuration"
print("PASS: World Builder preset, layout landmarks and safe scene separation")
