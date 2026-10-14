#if UNITY_EDITOR
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Aetherfall.Editor
{
    /// <summary>
    /// Deterministic prototype town builder. Runs in the Unity Editor, not on each
    /// player's device. Bakes an editable scene and keeps the login build untouched.
    /// Replace generated meshes with licensed modular prefabs as art becomes ready.
    /// </summary>
    public static class AetherfallWorldBuilder
    {
        private const string PresetPath = "Assets/WorldBuilder/starter-town.json";
        private const string ScenePath = "Assets/Scenes/StarterTown.unity";
        private const string MaterialsPath = "Assets/WorldBuilder/Materials";
        private static readonly Dictionary<string, Material> Materials = new Dictionary<string, Material>();

        [Serializable]
        public class TownPreset
        {
            public string townName = "Aetherfall Frontier";
            public int seed = 77421;
            public float width = 220f;
            public float depth = 190f;
            public int residentialHouses = 8;
            public int woodlandTrees = 130;
            public int bushes = 90;
            public float foliageOuterRadius = 195f;
        }

        [MenuItem("Aetherfall/World Builder/Generate Starter Town")]
        public static void GenerateStarterTown()
        {
            TownPreset preset = LoadPreset();
            var random = new System.Random(preset.seed);
            Materials.Clear();

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("Aetherfall World - " + preset.townName);
            var terrain = Group(root.transform, "01 Terrain");
            var roads = Group(root.transform, "02 Roads and Plaza");
            var landmarks = Group(root.transform, "03 Named Landmarks");
            var defenses = Group(root.transform, "04 Town Walls and South Gate");
            var residences = Group(root.transform, "05 Residences");
            var greenery = Group(root.transform, "06 Outdoor Foliage");
            var lights = Group(root.transform, "07 Lamps and Lighting");

            float halfWidth = preset.width * .5f;
            float halfDepth = preset.depth * .5f;
            Box(terrain, "Outer Landscape", Vector3.down * .7f,
                new Vector3(preset.foliageOuterRadius * 2.5f, 1.3f,
                    preset.foliageOuterRadius * 2.5f), "MossGrass", "#567D49", true);
            Box(terrain, "Town Ground", new Vector3(0, -.12f, 0),
                new Vector3(preset.width, .3f, preset.depth), "TownGrass", "#819962", true);

            // Orthogonal readable streets; only the central avenue leads through the gate.
            Box(roads, "South-North Main Road", new Vector3(0, .052f, -22),
                new Vector3(11f, .12f, preset.depth + 82f), "PackedEarth", "#B2A18A", false);
            Box(roads, "West-East Market Street", new Vector3(0, .052f, 5),
                new Vector3(preset.width - 24f, .12f, 8.5f), "PackedEarth", "#B2A18A", false);
            Box(roads, "Central Square Paving", new Vector3(0, .091f, 0),
                new Vector3(34f, .12f, 34f), "Stone", "#B5ACA0", false);
            for (int i = -3; i <= 3; i++)
            {
                Box(roads, "Square Stone Stripe " + i, new Vector3(i * 4.5f, .159f, 0),
                    new Vector3(.18f, .025f, 33), "Mortar", "#857F73", false);
            }

            // Stone walls. A deliberate 18 m opening at the SOUTH (-Z) gate.
            float wallY = 4f;
            float wallHeight = 8.5f;
            Box(defenses, "North Curtain Wall", new Vector3(0, wallY, halfDepth),
                new Vector3(preset.width + 5, wallHeight, 3.8f), "TownStone", "#898F95", true);
            Box(defenses, "West Curtain Wall", new Vector3(-halfWidth, wallY, 0),
                new Vector3(4, wallHeight, preset.depth + 5), "TownStone", "#898F95", true);
            Box(defenses, "East Curtain Wall", new Vector3(halfWidth, wallY, 0),
                new Vector3(4, wallHeight, preset.depth + 5), "TownStone", "#898F95", true);
            float curtainLength = (preset.width - 18f) / 2f;
            Box(defenses, "South West Wall", new Vector3(-(18f + curtainLength) / 2, wallY, -halfDepth),
                new Vector3(curtainLength, wallHeight, 4), "TownStone", "#898F95", true);
            Box(defenses, "South East Wall", new Vector3((18f + curtainLength) / 2, wallY, -halfDepth),
                new Vector3(curtainLength, wallHeight, 4), "TownStone", "#898F95", true);
            Tower(defenses, "South Gate West Tower", -13.3f, -halfDepth);
            Tower(defenses, "South Gate East Tower", 13.3f, -halfDepth);
            Box(defenses, "Gate Arch Lintel", new Vector3(0, 12.2f, -halfDepth),
                new Vector3(23f, 3.2f, 6), "TownStone", "#898F95", true);
            Box(defenses, "Gate Crest", new Vector3(0, 14.2f, -halfDepth),
                new Vector3(8f, 2.8f, 6.2f), "RoofSlate", "#55566C", true);

            // Landmark sizes are intentional for legibility on a mobile screen.
            Fountain(landmarks, new Vector3(0, 0, 0));
            House(landmarks, "Adventurers Guild", new Vector3(0, 0, 68), 29, 19, 12, "#C9B59B", "#475C7D");
            House(landmarks, "The Hearth Inn", new Vector3(-68, 0, -34), 23, 17, 10.5f, "#D6C5A7", "#78604E");
            House(landmarks, "Blacksmith and Forge", new Vector3(67, 0, -34), 24, 17, 9.5f, "#99968C", "#4F505B");
            House(landmarks, "General Supply Shop", new Vector3(-64, 0, 38), 19, 16, 9, "#DCC6A4", "#627A67");
            House(landmarks, "Healing Shrine", new Vector3(67, 0, 52), 21, 19, 11, "#C7CFDC", "#6C79A1");
            House(landmarks, "Bakery", new Vector3(-37, 0, -64), 18, 13, 8, "#C4A67B", "#755C57");
            House(landmarks, "Apothecary", new Vector3(38, 0, -63), 18, 13, 8, "#C3B7A3", "#5D8176");
            Market(landmarks, new Vector3(75, 0, 9));
            TrainingYard(landmarks, new Vector3(80, 0, -70));

            // Repeatable residential blockout. These are editable individual objects.
            var residentialSlots = new []
            {
                new Vector3(-85,0,73), new Vector3(-39,0,73), new Vector3(39,0,74),
                new Vector3(-89,0,-70), new Vector3(-63,0,-68),
                new Vector3(63,0,77), new Vector3(-91,0,-4), new Vector3(91,0,66)
            };
            int houseCount = Mathf.Clamp(preset.residentialHouses, 0, residentialSlots.Length);
            for (int i = 0; i < houseCount; i++)
            {
                var pos = residentialSlots[i];
                float w = 11f + (float)random.NextDouble() * 3.5f;
                float d = 10f + (float)random.NextDouble() * 2.5f;
                House(residences, "Residence " + (i + 1), pos, w, d, 6.7f, "#C5B6A0", "#6E6255");
            }

            // Foliage lives primarily beyond the walls, preventing the road-clipping
            // issues from earlier prototypes. The same seed always yields the same town.
            for (int i = 0; i < preset.woodlandTrees; i++)
            {
                float x = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                float z = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                if (Mathf.Abs(x) < halfWidth + 13 && Mathf.Abs(z) < halfDepth + 13) continue;
                if (Mathf.Abs(x) < 13 && z < -halfDepth) continue;
                Tree(greenery, "Tree " + i, new Vector3(x, 0, z),
                    7 + (float)random.NextDouble() * 6,
                    (float)random.NextDouble() > .42f);
            }
            for (int i = 0; i < preset.bushes; i++)
            {
                float x = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                float z = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                if (Mathf.Abs(x) < 19 && Mathf.Abs(z) < halfDepth + 38) continue;
                if (Mathf.Abs(x) < halfWidth + 5 && Mathf.Abs(z) < halfDepth + 5) continue;
                Sphere(greenery, "Shrub " + i, new Vector3(x, 1, z),
                    new Vector3(2.6f, 2.1f, 2.7f), "DarkLeaves", "#486945", false);
            }

            for (int i = -3; i <= 3; i++)
            {
                Lamp(lights, new Vector3(-8.5f, 0, i * 21f));
                Lamp(lights, new Vector3(8.5f, 0, i * 21f));
            }
            var sun = new GameObject("Sun (Baked-light candidate)");
            sun.transform.SetParent(lights, false);
            sun.transform.rotation = Quaternion.Euler(43, -35, 0);
            var sunLight = sun.AddComponent<Light>();
            sunLight.type = LightType.Directional;
            sunLight.intensity = 1.05f;
            sunLight.shadows = LightShadows.Soft;
            RenderSettings.ambientLight = new Color(.67f, .74f, .84f);

            var cameraObject = new GameObject("Preview Camera (replace with player camera)");
            cameraObject.transform.SetParent(root.transform, false);
            cameraObject.transform.position = new Vector3(0, 178, -190);
            cameraObject.transform.LookAt(new Vector3(0, 0, 0));
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(.66f, .79f, .9f);
            camera.fieldOfView = 61;
            camera.farClipPlane = 700;
            camera.tag = "MainCamera";

            Directory.CreateDirectory("Assets/Scenes");
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
                throw new InvalidOperationException("Could not save starter town scene.");
            AssetDatabase.SaveAssets();
            Debug.Log("Aetherfall World Builder: saved deterministic prototype at " + ScenePath +
                ". Seed=" + preset.seed + "; startup scene left unchanged.");
        }

        private static TownPreset LoadPreset()
        {
            if (!File.Exists(PresetPath))
                throw new FileNotFoundException("Missing Aetherfall World Builder preset", PresetPath);
            TownPreset settings = JsonUtility.FromJson<TownPreset>(File.ReadAllText(PresetPath));
            if (settings == null || settings.width < 180 || settings.depth < 150 ||
                settings.foliageOuterRadius < settings.width * .65f)
                throw new ArgumentException("Town dimensions are incompatible with landmark positions.");
            return settings;
        }

        private static Transform Group(Transform parent, string name)
        {
            var group = new GameObject(name);
            group.transform.SetParent(parent, false);
            return group.transform;
        }

        private static Material Surface(string label, string hex)
        {
            if (Materials.TryGetValue(label, out Material existing)) return existing;
            Material persisted = AssetDatabase.LoadAssetAtPath<Material>(MaterialsPath + "/" + label + ".mat");
            if (persisted == null)
            {
                if (!AssetDatabase.IsValidFolder(MaterialsPath))
                {
                    if (!AssetDatabase.IsValidFolder("Assets/WorldBuilder"))
                        AssetDatabase.CreateFolder("Assets", "WorldBuilder");
                    AssetDatabase.CreateFolder("Assets/WorldBuilder", "Materials");
                }
                var shader = Shader.Find("Universal Render Pipeline/Lit") ?? Shader.Find("Standard");
                if (shader == null) throw new InvalidOperationException("No compatible Unity material shader found.");
                persisted = new Material(shader);
                AssetDatabase.CreateAsset(persisted, MaterialsPath + "/" + label + ".mat");
            }
            if (ColorUtility.TryParseHtmlString(hex, out Color color))
            {
                persisted.color = color;
                if (persisted.HasProperty("_BaseColor")) persisted.SetColor("_BaseColor", color);
                EditorUtility.SetDirty(persisted);
            }
            Materials[label] = persisted;
            return persisted;
        }

        private static GameObject Primitive(Transform parent, string name, PrimitiveType type,
            Vector3 position, Vector3 scale, string material, string hex, bool solid)
        {
            GameObject go = GameObject.CreatePrimitive(type);
            go.name = name;
            go.transform.SetParent(parent, false);
            go.transform.localPosition = position;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = Surface(material, hex);
            if (!solid)
            {
                var collider = go.GetComponent<Collider>();
                if (collider != null) UnityEngine.Object.DestroyImmediate(collider);
            }
            return go;
        }

        private static GameObject Box(Transform t, string name, Vector3 p, Vector3 s,
            string m, string c, bool solid = true) =>
            Primitive(t, name, PrimitiveType.Cube, p, s, m, c, solid);

        private static GameObject Cylinder(Transform t, string name, Vector3 p, Vector3 s,
            string m, string c, bool solid = true) =>
            Primitive(t, name, PrimitiveType.Cylinder, p, s, m, c, solid);

        private static GameObject Sphere(Transform t, string name, Vector3 p, Vector3 s,
            string m, string c, bool solid = false) =>
            Primitive(t, name, PrimitiveType.Sphere, p, s, m, c, solid);

        private static void House(Transform parent, string name, Vector3 p,
            float width, float depth, float height, string wallColor, string roofColor)
        {
            Transform plot = Group(parent, name);
            plot.localPosition = p;
            Box(plot, "Stone Foundation", new Vector3(0, .28f, 0),
                new Vector3(width + 1f, .55f, depth + 1), "Stone", "#B5ACA0");
            Box(plot, "Plaster / Timber Walls", new Vector3(0, height / 2 + .48f, 0),
                new Vector3(width, height, depth), "WarmPlaster", wallColor);
            var roofLeft = Box(plot, "Pitched Roof Left", new Vector3(-width * .24f, height + 2f, 0),
                new Vector3(width * .61f, .7f, depth + 2.5f), "RoofSlate", roofColor);
            roofLeft.transform.localRotation = Quaternion.Euler(0, 0, 27);
            var roofRight = Box(plot, "Pitched Roof Right", new Vector3(width * .24f, height + 2f, 0),
                new Vector3(width * .61f, .7f, depth + 2.5f), "RoofSlate", roofColor);
            roofRight.transform.localRotation = Quaternion.Euler(0, 0, -27);
            Box(plot, "Wooden Door South", new Vector3(0, 1.9f, -depth * .5f - .09f),
                new Vector3(2.5f, 3.75f, .23f), "Timber", "#77543B");
            Box(plot, "Left Window", new Vector3(-width * .28f, height * .53f, -depth * .5f - .13f),
                new Vector3(2.2f, 2.5f, .1f), "Window", "#739CA5", false);
            Box(plot, "Right Window", new Vector3(width * .28f, height * .53f, -depth * .5f - .13f),
                new Vector3(2.2f, 2.5f, .1f), "Window", "#739CA5", false);
        }

        private static void Tower(Transform parent, string name, float x, float z)
        {
            var t = Group(parent, name);
            t.localPosition = new Vector3(x, 0, z);
            Cylinder(t, "Stone Base", new Vector3(0, 6, 0),
                new Vector3(5.5f, 6, 5.5f), "TownStone", "#898F95");
            Cylinder(t, "Battlement Top", new Vector3(0, 13, 0),
                new Vector3(6.2f, 1.1f, 6.2f), "Stone", "#B5ACA0");
        }

        private static void Fountain(Transform parent, Vector3 p)
        {
            var root = Group(parent, "Central Fountain Landmark");
            root.localPosition = p;
            Cylinder(root, "Fountain Stone Plinth", new Vector3(0, .62f, 0),
                new Vector3(6.1f, .62f, 6.1f), "Stone", "#B5ACA0");
            Cylinder(root, "Fountain Basin", new Vector3(0, 1.5f, 0),
                new Vector3(5.2f, .46f, 5.2f), "TownStone", "#898F95");
            Cylinder(root, "Still Water Placeholder", new Vector3(0, 2.01f, 0),
                new Vector3(4.55f, .055f, 4.55f), "Water", "#6DACC3", false);
            Cylinder(root, "Fountain Spire", new Vector3(0, 3.7f, 0),
                new Vector3(.8f, 2.3f, .8f), "Stone", "#B5ACA0");
        }

        private static void Market(Transform parent, Vector3 p)
        {
            var root = Group(parent, "Market Stalls");
            root.localPosition = p;
            for (int i = 0; i < 3; i++)
            {
                var x = (i - 1) * 11f;
                Box(root, "Stall Counter " + i, new Vector3(x, 1.4f, 0),
                    new Vector3(7f, 1.1f, 3.2f), "Timber", "#77543B");
                Box(root, "Stall Canopy " + i, new Vector3(x, 4.7f, 0),
                    new Vector3(8.6f, .3f, 5.2f), "Awning", "#9E6856", false);
            }
        }

        private static void TrainingYard(Transform parent, Vector3 p)
        {
            var root = Group(parent, "Combat Training Yard");
            root.localPosition = p;
            Box(root, "Packed Training Ground", new Vector3(0, .04f, 0),
                new Vector3(26f, .09f, 18f), "PackedEarth", "#B2A18A", false);
            for (int i = -1; i <= 1; i++)
            {
                Cylinder(root, "Wooden Practice Dummy Post " + i,
                    new Vector3(i * 7f, 1.65f, 0), new Vector3(.65f, 1.65f, .65f),
                    "Timber", "#77543B");
                Box(root, "Practice Dummy Arms " + i, new Vector3(i * 7f, 2.5f, 0),
                    new Vector3(3.2f, .3f, .3f), "Timber", "#77543B");
            }
        }

        private static void Tree(Transform parent, string name, Vector3 p, float height, bool pine)
        {
            Transform tree = Group(parent, name);
            tree.localPosition = p;
            Cylinder(tree, "Tree Trunk", new Vector3(0, height * .31f, 0),
                new Vector3(.46f, height * .31f, .46f), "Timber", "#77543B");
            if (pine)
            {
                // Three cone-like tiers, approximate with cylinders to stay editor-native.
                for (int j = 0; j < 3; j++)
                    Sphere(tree, "Pine Foliage Tier " + j,
                        new Vector3(0, height * (.53f + .17f * j), 0),
                        new Vector3(5.6f - j * 1.3f, 4.6f - j * .5f, 5.6f - j * 1.3f),
                        "DarkLeaves", "#486945", false);
            }
            else
                Sphere(tree, "Broad Leaf Crown", new Vector3(0, height * .8f, 0),
                    new Vector3(6.4f, 6.2f, 6.3f), "DarkLeaves", "#486945", false);
        }

        private static void Lamp(Transform parent, Vector3 p)
        {
            Cylinder(parent, "Lantern Post", p + Vector3.up * 2.25f,
                new Vector3(.21f, 2.25f, .21f), "Timber", "#77543B");
            Sphere(parent, "Lantern Glow (unlit)", p + Vector3.up * 4.6f,
                Vector3.one * 1.4f, "Lantern", "#F5D9A1", false);
        }
    }
}
#endif
