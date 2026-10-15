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
        private const string TerrainAssetPath = "Assets/WorldBuilder/Generated/StarterTownTerrain.asset";
        private static float guildHillHeight = 6f;
        private static readonly Dictionary<string, Material> Materials = new Dictionary<string, Material>();

        [Serializable]
        public class TownPreset
        {
            public string townName = "Aetherfall Frontier";
            public int seed = 77421;
            public float width = 250f;
            public float depth = 240f;
            public int residentialHouses = 8;
            public int woodlandTrees = 130;
            public int bushes = 90;
            public float foliageOuterRadius = 195f;
            public float guildHillHeight = 6f;
        }

        [MenuItem("Aetherfall/World Builder/Generate Starter Town")]
        public static void GenerateStarterTown()
        {
            TownPreset preset = LoadPreset();
            var random = new System.Random(preset.seed);
            Materials.Clear();
            guildHillHeight = Mathf.Clamp(preset.guildHillHeight, 0f, 12f);

            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = new GameObject("Aetherfall World - " + preset.townName);
            var terrain = Group(root.transform, "01 Terrain");
            var roads = Group(root.transform, "02 Roads and Plaza");
            var landmarks = Group(root.transform, "03 Named Landmarks");
            var defenses = Group(root.transform, "04 Town Walls and South Gate");
            var residences = Group(root.transform, "05 Residences");
            var greenery = Group(root.transform, "06 Outdoor Foliage");
            var lights = Group(root.transform, "07 Lamps and Lighting");
            var navigation = Group(root.transform, "08 Player and Quest Markers");

            // An irregular walled settlement, NOT a rectangular courtyard.
            // The main entrance opens directly into a busy circular market square.
            // A winding road travels round cottage blocks to the quieter guild quarter.
            Box(terrain, "Outer Meadow Ground", Vector3.down * .7f,
                new Vector3(preset.foliageOuterRadius * 2.5f, 1.3f,
                    preset.foliageOuterRadius * 2.5f), "MossGrass", "#648257", true);

            // A gently elevated northern guild terrace overlooks the gate district.
            // Save the terrain mesh as an asset so the baked town scene works on Android.
            BuildLandscapeMesh(terrain, preset.foliageOuterRadius * 1.25f);

            // South gate (-Z) -> market district -> winding guild road.
            // Circular market loop deliberately leaves the fountain clear.
            CurvedRoad(roads, "Arrival Road to Gate", 10f,
                new Vector2(0, -146), new Vector2(0, -122), new Vector2(0, -102),
                new Vector2(-1, -91), new Vector2(0, -86));
            RingRoad(roads, "Gate Market Loop Road", new Vector2(0, -64), 24f, 8f);
            Cylinder(roads, "Rounded Market Plaza", new Vector3(0, .038f, -64),
                new Vector3(18f, .055f, 18f), "PlazaStone", "#AEA497", false);

            CurvedRoad(roads, "Winding Guild Approach", 7.8f,
                new Vector2(-16, -45), new Vector2(-29, -27),
                new Vector2(-28, -7), new Vector2(-43, 15),
                new Vector2(-39, 35), new Vector2(-30, 54),
                new Vector2(-22, 72));
            CurvedRoad(roads, "Residential Return Lane", 6.6f,
                new Vector2(22, -54), new Vector2(46, -35),
                new Vector2(45, -13), new Vector2(45, 9),
                new Vector2(37, 29), new Vector2(17, 47),
                new Vector2(-6, 60), new Vector2(-22, 72));
            CurvedRoad(roads, "Blacksmith Side Lane", 5.8f,
                new Vector2(24, -66), new Vector2(49, -67),
                new Vector2(72, -65));
            CurvedRoad(roads, "Market Shopfront Spur", 5.6f,
                new Vector2(-23, -66), new Vector2(-48, -69),
                new Vector2(-65, -57));
            CurvedRoad(roads, "Shrine Footpath", 4.4f,
                new Vector2(37, 29), new Vector2(54, 49),
                new Vector2(66, 67));
            CurvedRoad(roads, "Guild Hall Forecourt", 7.0f,
                new Vector2(-22, 72), new Vector2(-22, 78),
                new Vector2(-22, 83));

            // Segmented perimeter follows a soft, irregular silhouette.
            // Gap between x=-9 and x=+9 is an 18-m south gate opening.
            Vector2[] wallOutline = {
                new Vector2(9, -104), new Vector2(42, -107),
                new Vector2(86, -96), new Vector2(109, -68),
                new Vector2(124, -19), new Vector2(115, 31),
                new Vector2(93, 78), new Vector2(56, 102),
                new Vector2(5, 119), new Vector2(-48, 110),
                new Vector2(-93, 85), new Vector2(-117, 46),
                new Vector2(-121, 5), new Vector2(-111, -48),
                new Vector2(-83, -88), new Vector2(-43, -104),
                new Vector2(-9, -104)
            };
            for (int i = 0; i < wallOutline.Length - 1; i++)
                WallSegment(defenses, "Curved Wall Segment " + (i + 1),
                    wallOutline[i], wallOutline[i + 1], 8.5f, 3.8f);
            Tower(defenses, "South Gate West Tower", -13.3f, -104);
            Tower(defenses, "South Gate East Tower", 13.3f, -104);
            Box(defenses, "Gate Arch Lintel", new Vector3(0, 12.2f, -104),
                new Vector3(23f, 3.2f, 6), "TownStone", "#898F95", true);
            Box(defenses, "Gate Crest", new Vector3(0, 14.2f, -104),
                new Vector3(8f, 2.8f, 6.2f), "RoofSlate", "#55566C", true);

            // Bustling gate-side market district (southern half).
            Fountain(landmarks, GroundPosition(0, -64));
            Market(landmarks, GroundPosition(-45, -84));
            House(landmarks, "General Supply Shop", GroundPosition(-77, -52),
                19, 16, 9, "#DCC6A4", "#627A67");
            House(landmarks, "Bakery", GroundPosition(39, -82),
                17, 13, 8, "#C4A67B", "#755C57");
            House(landmarks, "Blacksmith and Forge", GroundPosition(90, -54),
                23, 17, 9.5f, "#99968C", "#4F505B");
            House(landmarks, "Apothecary", GroundPosition(74, -10),
                19, 14, 8, "#C3B7A3", "#5D8176");
            House(landmarks, "The Hearth Inn", GroundPosition(-69, -19),
                23, 17, 10.5f, "#D6C5A7", "#78604E");

            // Guild Hall serves as Town Hall. The guildmaster governs the starter
            // town, registers newcomers, coordinates guards and posts town quests.
            House(landmarks, "Town Guild Hall - Civic Government", GroundPosition(-22, 96),
                29, 19, 12, "#C9B59B", "#475C7D");
            GuildHallDetails(landmarks, GroundPosition(-22, 96), 29f, 19f);
            GuildNoticeBoards(landmarks, GroundPosition(5, 83));
            TrainingYard(landmarks, GroundPosition(-77, 76));
            House(landmarks, "Healing Shrine", GroundPosition(72, 82),
                21, 19, 11, "#C7CFDC", "#6C79A1");

            // Repeatable residential blockout. These are editable individual objects.
            var residentialSlots = new []
            {
                GroundPosition(-90, 14), GroundPosition(-78, 42),
                GroundPosition(-54, 55), GroundPosition(7, 4),
                GroundPosition(83, 25), GroundPosition(75, 47),
                GroundPosition(18, 27), GroundPosition(-75, -81)
            };
            int houseCount = Mathf.Clamp(preset.residentialHouses, 0, residentialSlots.Length);
            for (int i = 0; i < houseCount; i++)
            {
                var pos = residentialSlots[i];
                pos.y = GroundHeight(pos.x, pos.z);
                float w = 11f + (float)random.NextDouble() * 3.5f;
                float d = 10f + (float)random.NextDouble() * 2.5f;
                House(residences, "Residence " + (i + 1), pos, w, d, 6.7f, "#C5B6A0", "#6E6255");
            }

            // Explicit entry/interaction anchors for the first playable prototype.
            // They are empty transforms, so they cannot block player movement.
            Marker(navigation, "Player Spawn - Inside South Gate", 0f, -93f, 1f);
            Marker(navigation, "Town Market Interaction Center", 0f, -64f, 1f);
            Marker(navigation, "Guild Registration Arrival", -22f, 81f, 1f);
            Marker(navigation, "Starter Field Exit - Beyond Gate", 0f, -130f, 1f);

            // Boundary-focused woodland: leave the winding streets and gate clear.
            for (int i = 0; i < preset.woodlandTrees; i++)
            {
                float x = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                float z = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                if (Mathf.Abs(x) < 141f && Mathf.Abs(z) < 136f) continue;
                if (Mathf.Abs(x) < 14 && z < -103) continue;
                Tree(greenery, "Tree " + i, GroundPosition(x, z),
                    7 + (float)random.NextDouble() * 6,
                    (float)random.NextDouble() > .42f);
            }
            for (int i = 0; i < preset.bushes; i++)
            {
                float x = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                float z = (float)(random.NextDouble() * 2 - 1) * preset.foliageOuterRadius;
                if (Mathf.Abs(x) < 136f && Mathf.Abs(z) < 130f) continue;
                if (Mathf.Abs(x) < 20f && z < -90) continue;
                Sphere(greenery, "Shrub " + i, GroundPosition(x, z) + Vector3.up,
                    new Vector3(2.6f, 2.1f, 2.7f), "DarkLeaves", "#486945", false);
            }

            // Light the entrance, then guide the player along the guild approach.
            foreach (Vector2 lamp in new[] {
                new Vector2(-11, -116), new Vector2(11, -116),
                new Vector2(-35, -39), new Vector2(-43, 8),
                new Vector2(-39, 46), new Vector2(-33, 76),
                new Vector2(39, -37), new Vector2(45, 13) })
                Lamp(lights, GroundPosition(lamp.x, lamp.y));
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
            cameraObject.transform.position = new Vector3(0, 185, -204);
            cameraObject.transform.LookAt(GroundPosition(0, -4));
            var camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(.66f, .79f, .9f);
            camera.fieldOfView = 61;
            camera.farClipPlane = 700;
            camera.tag = "MainCamera";

            Directory.CreateDirectory(Path.Combine(Application.dataPath, "Scenes"));
            EditorSceneManager.MarkSceneDirty(scene);
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
                throw new InvalidOperationException("Could not save starter town scene.");
            AssetDatabase.SaveAssets();
            Debug.Log("Aetherfall World Builder: saved deterministic prototype at " + ScenePath +
                ". Seed=" + preset.seed + "; startup scene left unchanged.");
        }

        private static TownPreset LoadPreset()
        {
            // Do not rely on the shell's current working directory. Unity Cloud,
            // batchmode, and local editors can be invoked from different folders.
            string absolutePreset = Path.Combine(Application.dataPath,
                "WorldBuilder", "starter-town.json");
            if (!File.Exists(absolutePreset))
                throw new FileNotFoundException(
                    "Missing Aetherfall World Builder preset", absolutePreset);
            TownPreset settings = JsonUtility.FromJson<TownPreset>(
                File.ReadAllText(absolutePreset));
            if (settings == null || settings.width < 180 || settings.depth < 150 ||
                settings.foliageOuterRadius < settings.width * .65f ||
                settings.guildHillHeight < 0 || settings.guildHillHeight > 12f)
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
            // Distinct palettes per building need distinct persisted materials.
            string key = label + "_" + hex.TrimStart('#');
            if (Materials.TryGetValue(key, out Material existing)) return existing;
            Material persisted = AssetDatabase.LoadAssetAtPath<Material>(MaterialsPath + "/" + key + ".mat");
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
                AssetDatabase.CreateAsset(persisted, MaterialsPath + "/" + key + ".mat");
            }
            if (ColorUtility.TryParseHtmlString(hex, out Color color))
            {
                persisted.color = color;
                if (persisted.HasProperty("_BaseColor")) persisted.SetColor("_BaseColor", color);
                EditorUtility.SetDirty(persisted);
            }
            Materials[key] = persisted;
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

        private static void Marker(Transform parent, string name,
            float x, float z, float standingOffset)
        {
            var marker = new GameObject(name);
            marker.transform.SetParent(parent, false);
            marker.transform.localPosition =
                GroundPosition(x, z) + Vector3.up * standingOffset;
        }

        private static void WallSegment(Transform parent, string label,
            Vector2 from, Vector2 to, float height, float thickness)
        {
            // Follow changes in ground elevation by using short level wall blocks.
            float length = Vector2.Distance(from, to);
            int pieces = Mathf.Max(1, Mathf.CeilToInt(length / 8f));
            for (int i = 0; i < pieces; i++)
            {
                Vector2 a = Vector2.Lerp(from, to, i / (float)pieces);
                Vector2 b = Vector2.Lerp(from, to, (i + 1f) / pieces);
                Vector3 start = GroundPosition(a.x, a.y);
                Vector3 end = GroundPosition(b.x, b.y);
                Vector3 heading = new Vector3(end.x - start.x, 0f, end.z - start.z);
                Vector3 mid = (start + end) * .5f;
                var block = Box(parent, label + " / " + i,
                    mid + Vector3.up * (height * .5f),
                    new Vector3(thickness, height + .5f, heading.magnitude + .25f),
                    "TownStone", "#898F95", true);
                block.transform.rotation = Quaternion.LookRotation(heading.normalized, Vector3.up);
            }
        }

        private static void RingRoad(Transform parent, string name,
            Vector2 center, float radius, float width)
        {
            const int segments = 32;
            var points = new Vector2[segments + 1];
            for (int i = 0; i <= segments; i++)
            {
                float angle = (i / (float)segments) * Mathf.PI * 2f;
                points[i] = center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * radius;
            }
            PolylineRoad(parent, name, width, points);
        }

        private static void CurvedRoad(Transform parent, string name, float width,
            params Vector2[] controlPoints)
        {
            // Catmull-Rom creates a bend without sharp 90-degree junctions.
            if (controlPoints.Length < 2) return;
            var points = new List<Vector2>();
            const int divisions = 5;
            for (int i = 0; i < controlPoints.Length - 1; i++)
            {
                Vector2 p0 = controlPoints[Mathf.Max(0, i - 1)];
                Vector2 p1 = controlPoints[i];
                Vector2 p2 = controlPoints[i + 1];
                Vector2 p3 = controlPoints[Mathf.Min(controlPoints.Length - 1, i + 2)];
                for (int j = 0; j < divisions; j++)
                {
                    float t = j / (float)divisions;
                    float t2 = t * t;
                    float t3 = t2 * t;
                    points.Add(.5f * (2f * p1 +
                        (-p0 + p2) * t +
                        (2f * p0 - 5f * p1 + 4f * p2 - p3) * t2 +
                        (-p0 + 3f * p1 - 3f * p2 + p3) * t3));
                }
            }
            points.Add(controlPoints[controlPoints.Length - 1]);
            PolylineRoad(parent, name, width, points.ToArray());
        }

        private static void PolylineRoad(Transform parent, string name, float width,
            Vector2[] points)
        {
            Transform road = Group(parent, name);
            for (int i = 0; i < points.Length - 1; i++)
            {
                Vector3 a = GroundPosition(points[i].x, points[i].y) + Vector3.up * .14f;
                Vector3 b = GroundPosition(points[i + 1].x, points[i + 1].y) + Vector3.up * .14f;
                Vector3 direction = b - a;
                if (direction.sqrMagnitude < .0001f) continue;
                GameObject segment = Box(road, "Road Surface " + i, (a + b) / 2f,
                    new Vector3(width, .12f, direction.magnitude + .22f),
                    "PackedEarth", "#B2A18A", false);
                segment.transform.rotation = Quaternion.LookRotation(direction.normalized, Vector3.up);
            }
        }


        private static float GroundHeight(float x, float z)
        {
            // Smooth 0-6 m climb from the market to the administrative guild
            // hill, with a wide, near-level plateau around the guild building.
            float north = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(-10f, 88f, z));
            float lateral = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.InverseLerp(24f, 89f, Mathf.Abs(x + 22f)));
            return guildHillHeight * north * (.13f + .87f * lateral);
        }

        private static Vector3 GroundPosition(float x, float z)
        {
            return new Vector3(x, GroundHeight(x, z), z);
        }

        private static void BuildLandscapeMesh(Transform parent, float halfSpan)
        {
            // An actual saved, collidable terrain mesh; flat outer meadow sits
            // below its surface. Does not require a per-player terrain generator.
            const int divisions = 96;
            int width = divisions + 1;
            Vector3[] vertices = new Vector3[width * width];
            Vector2[] uv = new Vector2[vertices.Length];
            int[] tris = new int[divisions * divisions * 6];
            for (int z = 0; z < width; z++)
            for (int x = 0; x < width; x++)
            {
                float px = Mathf.Lerp(-halfSpan, halfSpan, x / (float)divisions);
                float pz = Mathf.Lerp(-halfSpan, halfSpan, z / (float)divisions);
                int index = z * width + x;
                vertices[index] = GroundPosition(px, pz);
                uv[index] = new Vector2(x / (float)divisions, z / (float)divisions);
                if (x == divisions || z == divisions) continue;
                int t = (z * divisions + x) * 6;
                int a = index, b = index + 1, c = index + width, d = c + 1;
                tris[t] = a; tris[t + 1] = c; tris[t + 2] = b;
                tris[t + 3] = b; tris[t + 4] = c; tris[t + 5] = d;
            }
            Mesh mesh = new Mesh();
            mesh.name = "Aetherfall Starter Town Rolling Terrain";
            mesh.vertices = vertices;
            mesh.uv = uv;
            mesh.triangles = tris;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();

            if (!AssetDatabase.IsValidFolder("Assets/WorldBuilder/Generated"))
                AssetDatabase.CreateFolder("Assets/WorldBuilder", "Generated");
            if (AssetDatabase.LoadAssetAtPath<Mesh>(TerrainAssetPath) != null)
                AssetDatabase.DeleteAsset(TerrainAssetPath);
            AssetDatabase.CreateAsset(mesh, TerrainAssetPath);

            var terrain = new GameObject("Walkable North Guild Hill",
                typeof(MeshFilter), typeof(MeshRenderer), typeof(MeshCollider));
            terrain.transform.SetParent(parent, false);
            terrain.GetComponent<MeshFilter>().sharedMesh = mesh;
            terrain.GetComponent<MeshCollider>().sharedMesh = mesh;
            terrain.GetComponent<MeshRenderer>().sharedMaterial =
                Surface("TownGrass", "#819962");
        }

        private static void GuildNoticeBoards(Transform parent, Vector3 position)
        {
            Transform civic = Group(parent, "Guild Civic Services and Notice Boards");
            civic.position = position;
            // Signposts are blockout placeholders; later replace with readable
            // guild charter, quest/contracts board and public announcements.
            foreach (var section in new[] {
                new { name = "Quest and Contract Board", x = -6f },
                new { name = "Public Notices and Town Orders", x = 0f },
                new { name = "New Adventurer Registration", x = 6f }
            })
            {
                Box(civic, section.name + " Board", new Vector3(section.x, 2.6f, 0f),
                    new Vector3(4.4f, 3.2f, .35f), "Timber", "#77543B", true);
                Box(civic, section.name + " Parchment", new Vector3(section.x, 2.6f, -.22f),
                    new Vector3(3.8f, 2.6f, .06f), "CivicParchment", "#DAC59C", false);
                Box(civic, section.name + " Support", new Vector3(section.x, 1.25f, .2f),
                    new Vector3(.3f, 2.5f, .3f), "Timber", "#77543B", true);
            }
        }

        private static void GuildHallDetails(
            Transform parent, Vector3 position, float width, float depth)
        {
            // The guild hall is also the town hall: wider entrance, civic blue
            // banners, golden crest and a simple covered reception porch.
            // Decorative parts have no colliders so they cannot snag players.
            var hall = Group(parent, "Guild Town Hall Details - Civic Identity");
            hall.localPosition = position;
            float front = -depth * .5f;

            Box(hall, "Civic Stone Entry Step",
                new Vector3(0f, .26f, front - 1.55f),
                new Vector3(7.2f, .46f, 2.8f), "Stone", "#B5ACA0", true);
            Box(hall, "Guild Entrance Porch Roof",
                new Vector3(0f, 7.4f, front - 2.0f),
                new Vector3(19f, .7f, 5.4f), "RoofSlate", "#475C7D", false);
            foreach (float x in new[] { -8.2f, 8.2f })
            {
                Box(hall, "Porch Pillar " + x,
                    new Vector3(x, 3.6f, front - 3.9f),
                    new Vector3(.55f, 7.2f, .55f), "Timber", "#77543B", false);
                Box(hall, "Guild Blue Banner " + x,
                    new Vector3(x * 1.25f, 9.2f, front - .23f),
                    new Vector3(2.5f, 4f, .16f), "GuildBlue", "#385A94", false);
                Box(hall, "Guild Banner Gold Device " + x,
                    new Vector3(x * 1.25f, 9.4f, front - .33f),
                    new Vector3(1.1f, 1.15f, .09f), "GuildGold", "#E5BC65", false);
            }
            Box(hall, "Guild Hall Door Frame",
                new Vector3(0f, 2.7f, front - .2f),
                new Vector3(3.5f, 5.0f, .5f), "Timber", "#77543B", false);
            Box(hall, "Guild Charter Crest",
                new Vector3(0f, 9.1f, front - .24f),
                new Vector3(3.6f, 3.6f, .25f), "GuildGold", "#E5BC65", false);
        }

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

            // Low-cost timber framing reads more like a stylized JRPG village
            // than bare cubes. These are visual-only, without new collision.
            foreach (float side in new[] { -1f, 1f })
            {
                Box(plot, "Front Timber Corner " + side,
                    new Vector3(side * (width * .5f - .25f), height * .5f + .4f, -depth * .5f - .12f),
                    new Vector3(.52f, height, .35f), "Timber", "#77543B", false);
                Box(plot, "Rear Timber Corner " + side,
                    new Vector3(side * (width * .5f - .25f), height * .5f + .4f, depth * .5f),
                    new Vector3(.5f, height, .42f), "Timber", "#77543B", false);
                float windowX = side * width * .28f;
                Box(plot, "Window Shutter " + side,
                    new Vector3(windowX + side * 1.36f, height * .53f, -depth * .5f - .19f),
                    new Vector3(.5f, 2.65f, .16f), "Timber", "#77543B", false);
            }
            Box(plot, "Front Exposed Timber Beam",
                new Vector3(0f, height * .86f + .48f, -depth * .5f - .13f),
                new Vector3(width, .36f, .35f), "Timber", "#77543B", false);
            Box(plot, "Roof Ridge Cap",
                new Vector3(0f, height + 3.9f, 0f),
                new Vector3(.75f, .65f, depth + 2.8f), "RoofSlate", roofColor, false);

            if (name.Contains("Inn") || name.Contains("Bakery"))
                Box(plot, "Stone Chimney",
                    new Vector3(width * .28f, height + 3.25f, depth * .19f),
                    new Vector3(1.8f, 5.1f, 1.8f), "TownStone", "#898F95", false);
        }

        private static void Tower(Transform parent, string name, float x, float z)
        {
            var t = Group(parent, name);
            t.localPosition = GroundPosition(x, z);
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
