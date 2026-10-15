using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Aetherfall.Exploration
{
    /// <summary>
    /// Emergency-safe, mobile-ready deterministic starter town preview.
    ///
    /// The baked Unity Editor scene is preferred. Some Unity Cloud configurations
    /// override EditorBuildSettings and package only the login scene. In that case
    /// this builder generates the SAME key town districts inside a new runtime
    /// scene, so Play as Guest always leads somewhere meaningful on Android.
    ///
    /// This is the intentionally simple first 3D blockout. It is NOT final art,
    /// account registration, multiplayer, or an offline copy of the full MMORPG.
    /// </summary>
    public static class AetherfallRuntimeTown
    {
        private static readonly Dictionary<string, Material> Palette =
            new Dictionary<string, Material>();
        private static Transform root;

        public static Scene CreateScene()
        {
            // SceneManager.CreateScene doesn't require a packaged *.unity scene.
            Scene town = SceneManager.CreateScene("StarterTown");
            if (!SceneManager.SetActiveScene(town))
                throw new InvalidOperationException(
                    "Cannot make the temporary StarterTown preview scene active.");

            Build();
            Debug.Log("AETHERFALL_GUEST_RUNTIME_WORLD_READY: StarterTown blockout generated on device.");
            return town;
        }

        private static void Build()
        {
            Palette.Clear();
            root = new GameObject("Aetherfall Frontier - Guest Runtime World").transform;
            var terrain = Group(root, "01 Meadow and Guild Hill");
            var streets = Group(root, "02 Streets and Plaza");
            var landmarks = Group(root, "03 Markets and Guild Buildings");
            var defenses = Group(root, "04 South Gate and Irregular Walls");
            var residences = Group(root, "05 Residential District");
            var nature = Group(root, "06 Tree Line");
            var lights = Group(root, "07 Sun and Lanterns");
            var markers = Group(root, "08 Quest and Player Markers");

            // 250 m starter settlement surrounded by 390 m of meadow.
            Box(terrain, "Outer Meadow", new Vector3(0f, -.83f, 0f),
                new Vector3(510f, 1.55f, 510f), "Meadow", "#647F54", true);
            BuildGroundMesh(terrain);

            // Walkable routes: south gate -> market square -> winding guild hill.
            Road(streets, "South Gate Arrival", 10f,
                new Vector2(0, -146), new Vector2(0, -122),
                new Vector2(0, -105), new Vector2(0, -93),
                new Vector2(0, -87));
            RingRoad(streets, new Vector2(0, -64), 24f, 8f);
            Cylinder(streets, "Market Plaza", new Vector3(0f, .025f, -64f),
                new Vector3(18f, .065f, 18f), "Plaza", "#AA9C87", false);
            Road(streets, "Winding Guild Approach", 7.8f,
                new Vector2(-16, -45), new Vector2(-29, -27),
                new Vector2(-28, -7), new Vector2(-43, 15),
                new Vector2(-39, 35), new Vector2(-30, 54), new Vector2(-22, 80));
            Road(streets, "Residential Loop", 6.6f,
                new Vector2(22, -54), new Vector2(46, -35),
                new Vector2(45, -13), new Vector2(45, 9),
                new Vector2(37, 29), new Vector2(17, 47),
                new Vector2(-6, 60), new Vector2(-22, 78));
            Road(streets, "Blacksmith Lane", 5.8f,
                new Vector2(24, -66), new Vector2(49, -67), new Vector2(72, -65));
            Road(streets, "Supply Shop Lane", 5.6f,
                new Vector2(-23, -66), new Vector2(-48, -69), new Vector2(-65, -57));
            Road(streets, "Shrine Footpath", 4.4f,
                new Vector2(37, 29), new Vector2(54, 49), new Vector2(66, 67));

            Vector2[] perimeter =
            {
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
            for (int i = 0; i < perimeter.Length - 1; i++)
                Wall(defenses, perimeter[i], perimeter[i + 1]);
            Tower(defenses, "South Gate West Watch Tower", -13.3f, -104f);
            Tower(defenses, "South Gate East Watch Tower", 13.3f, -104f);
            Box(defenses, "Gate Arch Bridge", new Vector3(0f, 12.2f, -104f),
                new Vector3(23f, 3.2f, 6f), "Stone", "#898F95", true);
            Box(defenses, "South Gate Crest", new Vector3(0f, 14.2f, -104f),
                new Vector3(8f, 2.8f, 6.2f), "Guild Blue", "#445878", false);

            Fountain(landmarks, new Vector3(0f, 0f, -64f));
            MarketStalls(landmarks, new Vector3(-45f, Height(-45f, -84f), -84f));
            House(landmarks, "General Supply Shop", -77f, -52f,
                  19f, 16f, 9f, "#DCC6A4", "#627A67");
            House(landmarks, "Bakery", 39f, -82f,
                  17f, 13f, 8f, "#C4A67B", "#755C57");
            House(landmarks, "Blacksmith and Forge", 90f, -54f,
                  23f, 17f, 9.5f, "#99968C", "#4F505B");
            House(landmarks, "Apothecary", 74f, -10f,
                  19f, 14f, 8f, "#C3B7A3", "#5D8176");
            House(landmarks, "The Hearth Inn", -69f, -19f,
                  23f, 17f, 10.5f, "#D6C5A7", "#78604E");
            House(landmarks, "Town Guild Hall - Civic Government", -22f, 96f,
                  29f, 19f, 12f, "#C9B59B", "#475C7D");
            GuildPorch(landmarks);
            NoticeBoards(landmarks);
            TrainingYard(landmarks);
            House(landmarks, "Healing Shrine", 72f, 82f,
                  21f, 19f, 11f, "#C7CFDC", "#6C79A1");

            var slots = new Vector2[]
            {
                new Vector2(-90, 14), new Vector2(-78, 42),
                new Vector2(-54, 55), new Vector2(7, 4),
                new Vector2(83, 25), new Vector2(75, 47),
                new Vector2(18, 27), new Vector2(-75, -81)
            };
            var random = new System.Random(77421);
            for (int i = 0; i < slots.Length; i++)
                House(residences, "Residence " + (i + 1), slots[i].x, slots[i].y,
                      11f + (float)random.NextDouble() * 3.5f,
                      10f + (float)random.NextDouble() * 2.5f, 6.7f,
                      "#C5B6A0", "#6E6255");

            // Surround the town, leaving roads, front gate, and walking lanes clear.
            for (int i = 0; i < 110; i++)
            {
                float x = (float)(random.NextDouble() * 2f - 1f) * 195f;
                float z = (float)(random.NextDouble() * 2f - 1f) * 195f;
                if (Mathf.Abs(x) < 141f && Mathf.Abs(z) < 136f) continue;
                if (Mathf.Abs(x) < 18f && z < -101f) continue;
                Tree(nature, "Woodland Tree " + i, x, z,
                    7f + (float)random.NextDouble() * 6f,
                    random.NextDouble() > .42);
            }
            for (int i = 0; i < 65; i++)
            {
                float x = (float)(random.NextDouble() * 2f - 1f) * 195f;
                float z = (float)(random.NextDouble() * 2f - 1f) * 195f;
                if (Mathf.Abs(x) < 136f && Mathf.Abs(z) < 130f) continue;
                Sphere(nature, "Dark Green Bush " + i,
                    new Vector3(x, Height(x, z) + 1f, z),
                    new Vector3(2.7f, 2.1f, 2.7f), "Leaves", "#496D47", false);
            }
            foreach (var p in new[]
            {
                new Vector2(-11, -116), new Vector2(11, -116),
                new Vector2(-35, -39), new Vector2(-43, 8),
                new Vector2(-39, 46), new Vector2(-33, 76),
                new Vector2(39, -37), new Vector2(45, 13)
            })
            {
                Vector3 world = Point(p.x, p.y);
                Cylinder(lights, "Road Lantern Post",
                    world + Vector3.up * 2.2f, new Vector3(.2f, 2.2f, .2f),
                    "Wood", "#77543B", false);
                Sphere(lights, "Road Lantern Glow",
                    world + Vector3.up * 4.45f, Vector3.one * 1.25f,
                    "Lantern", "#F5D9A1", false);
            }
            var sun = new GameObject("Sunlight");
            sun.transform.SetParent(lights, false);
            sun.transform.rotation = Quaternion.Euler(43f, -35f, 0f);
            var sunlight = sun.AddComponent<Light>();
            sunlight.type = LightType.Directional;
            sunlight.intensity = 1.05f;
            sunlight.shadows = LightShadows.Soft;
            RenderSettings.ambientLight = new Color(.67f, .74f, .84f);

            Marker(markers, "Player Spawn - Inside South Gate", 0f, -93f);
            Marker(markers, "Town Market Interaction Center", 0f, -64f);
            Marker(markers, "Guild Registration Arrival", -22f, 81f);
            Marker(markers, "Starter Field Exit - Beyond Gate", 0f, -130f);

            new GameObject("Runtime Blockout Prototype - Not Final Game Art")
                .transform.SetParent(root, false);
        }

        private static Transform Group(Transform parent, string name)
        {
            var item = new GameObject(name).transform;
            item.SetParent(parent, false);
            return item;
        }

        private static float Height(float x, float z)
        {
            // Same broad north-guild-hill contour as the Editor prototype.
            float north = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(-10f, 88f, z));
            float side = 1f - Mathf.SmoothStep(0f, 1f,
                Mathf.InverseLerp(24f, 89f, Mathf.Abs(x + 22f)));
            return 6f * north * (.13f + .87f * side);
        }

        private static Vector3 Point(float x, float z)
        {
            return new Vector3(x, Height(x, z), z);
        }

        private static void BuildGroundMesh(Transform parent)
        {
            const int segments = 64;
            const float halfWidth = 243f;
            int side = segments + 1;
            var vertices = new Vector3[side * side];
            var triangles = new int[segments * segments * 6];
            for (int z = 0; z < side; z++)
            for (int x = 0; x < side; x++)
            {
                float px = Mathf.Lerp(-halfWidth, halfWidth, (float)x / segments);
                float pz = Mathf.Lerp(-halfWidth, halfWidth, (float)z / segments);
                vertices[z * side + x] = Point(px, pz);
                if (x == segments || z == segments) continue;
                int i = (z * segments + x) * 6;
                int a = z * side + x, b = a + 1, c = a + side, d = c + 1;
                triangles[i] = a; triangles[i + 1] = c; triangles[i + 2] = b;
                triangles[i + 3] = b; triangles[i + 4] = c; triangles[i + 5] = d;
            }
            var mesh = new Mesh { name = "Runtime Collidable Guild Hill" };
            mesh.vertices = vertices;
            mesh.triangles = triangles;
            mesh.RecalculateNormals();
            mesh.RecalculateBounds();
            var go = new GameObject("Walkable North Guild Hill",
                typeof(MeshFilter), typeof(MeshRenderer), typeof(MeshCollider));
            go.transform.SetParent(parent, false);
            go.GetComponent<MeshFilter>().sharedMesh = mesh;
            go.GetComponent<MeshCollider>().sharedMesh = mesh;
            go.GetComponent<MeshRenderer>().sharedMaterial = Surface("Hill", "#819962");
        }

        private static Material Surface(string name, string hex)
        {
            string key = name + hex;
            if (Palette.TryGetValue(key, out Material material)) return material;
            Shader shader = Shader.Find("Universal Render Pipeline/Lit") ??
                            Shader.Find("Standard") ??
                            Shader.Find("Unlit/Color") ??
                            Shader.Find("Sprites/Default");
            if (shader == null)
                throw new InvalidOperationException(
                    "Missing Unity shader required for StarterTown preview.");
            material = new Material(shader) { name = key };
            if (ColorUtility.TryParseHtmlString(hex, out Color color))
            {
                material.color = color;
                if (material.HasProperty("_BaseColor"))
                    material.SetColor("_BaseColor", color);
                if (material.HasProperty("_Color"))
                    material.SetColor("_Color", color);
            }
            Palette[key] = material;
            return material;
        }

        private static GameObject Shape(Transform parent, string name,
            PrimitiveType primitive, Vector3 pos, Vector3 scale,
            string materialName, string color, bool solid)
        {
            var item = GameObject.CreatePrimitive(primitive);
            item.name = name;
            item.transform.SetParent(parent, false);
            item.transform.localPosition = pos;
            item.transform.localScale = scale;
            item.GetComponent<Renderer>().sharedMaterial = Surface(materialName, color);
            if (!solid)
            {
                var collision = item.GetComponent<Collider>();
                if (collision != null) UnityEngine.Object.Destroy(collision);
            }
            return item;
        }

        private static GameObject Box(Transform parent, string name,
            Vector3 pos, Vector3 size, string materialName, string color,
            bool solid = true)
        {
            return Shape(parent, name, PrimitiveType.Cube, pos, size,
                         materialName, color, solid);
        }

        private static GameObject Cylinder(Transform parent, string name,
            Vector3 pos, Vector3 size, string materialName, string color,
            bool solid = true)
        {
            return Shape(parent, name, PrimitiveType.Cylinder, pos, size,
                         materialName, color, solid);
        }

        private static GameObject Sphere(Transform parent, string name,
            Vector3 pos, Vector3 size, string materialName, string color,
            bool solid = false)
        {
            return Shape(parent, name, PrimitiveType.Sphere, pos, size,
                         materialName, color, solid);
        }

        private static void Marker(Transform parent, string name, float x, float z)
        {
            var marker = new GameObject(name);
            marker.transform.SetParent(parent, false);
            marker.transform.localPosition = Point(x, z) + Vector3.up;
        }

        private static void Road(Transform parent, string name, float width,
                                 params Vector2[] points)
        {
            var road = Group(parent, name);
            // Short sections follow the climb without clipping into the hill.
            for (int i = 0; i < points.Length - 1; i++)
            {
                Vector3 a = Point(points[i].x, points[i].y) + Vector3.up * .12f;
                Vector3 b = Point(points[i + 1].x, points[i + 1].y) + Vector3.up * .12f;
                float distance = Vector3.Distance(a, b);
                int slices = Mathf.Max(1, Mathf.CeilToInt(distance / 7f));
                for (int s = 0; s < slices; s++)
                {
                    float t0 = (float)s / slices, t1 = (float)(s + 1) / slices;
                    Vector3 mid = Vector3.Lerp(a, b, (t0 + t1) * .5f);
                    Vector3 delta = (b - a) / slices;
                    var tile = Box(road, "Path Segment " + i + "-" + s,
                        mid, new Vector3(width, .12f, delta.magnitude + .22f),
                        "Road", "#B2A18A", false);
                    tile.transform.rotation = Quaternion.LookRotation(delta.normalized, Vector3.up);
                }
            }
        }

        private static void RingRoad(Transform parent, Vector2 center,
                                      float radius, float width)
        {
            var ring = Group(parent, "Gate Market Loop Road");
            const int sections = 30;
            for (int i = 0; i < sections; i++)
            {
                float a0 = (float)i / sections * Mathf.PI * 2f;
                float a1 = (float)(i + 1) / sections * Mathf.PI * 2f;
                Vector2 p0 = center + new Vector2(Mathf.Cos(a0), Mathf.Sin(a0)) * radius;
                Vector2 p1 = center + new Vector2(Mathf.Cos(a1), Mathf.Sin(a1)) * radius;
                Vector3 from = Point(p0.x, p0.y) + Vector3.up * .12f;
                Vector3 to = Point(p1.x, p1.y) + Vector3.up * .12f;
                Vector3 delta = to - from;
                var tile = Box(ring, "Market Ring " + i, (from + to) * .5f,
                    new Vector3(width, .13f, delta.magnitude + .22f),
                    "Road", "#B2A18A", false);
                tile.transform.rotation = Quaternion.LookRotation(delta.normalized, Vector3.up);
            }
        }

        private static void Wall(Transform parent, Vector2 from, Vector2 to)
        {
            float length = Vector2.Distance(from, to);
            int pieces = Mathf.Max(1, Mathf.CeilToInt(length / 8f));
            for (int i = 0; i < pieces; i++)
            {
                Vector2 a = Vector2.Lerp(from, to, (float)i / pieces);
                Vector2 b = Vector2.Lerp(from, to, (float)(i + 1) / pieces);
                Vector3 posA = Point(a.x, a.y);
                Vector3 posB = Point(b.x, b.y);
                Vector3 flat = new Vector3(posB.x - posA.x, 0f, posB.z - posA.z);
                var item = Box(parent, "Irregular Defensive Wall " + i,
                    (posA + posB) * .5f + Vector3.up * 4.25f,
                    new Vector3(3.8f, 8.7f, flat.magnitude + .3f),
                    "Stone", "#898F95", true);
                item.transform.rotation = Quaternion.LookRotation(flat.normalized);
            }
        }

        private static void Tower(Transform parent, string name, float x, float z)
        {
            var tower = Group(parent, name);
            tower.localPosition = Point(x, z);
            Cylinder(tower, "Round Stone Base",
                new Vector3(0f, 6f, 0f), new Vector3(5.5f, 6f, 5.5f),
                "Stone", "#898F95");
            Cylinder(tower, "Battlement",
                new Vector3(0f, 13f, 0f), new Vector3(6.2f, 1.1f, 6.2f),
                "Foundation", "#B5ACA0");
        }

        private static void House(Transform parent, string name, float x, float z,
            float width, float depth, float height, string plaster, string roofing)
        {
            var house = Group(parent, name);
            house.localPosition = Point(x, z);
            Box(house, "Foundation", new Vector3(0, .28f, 0),
                new Vector3(width + 1f, .55f, depth + 1f),
                "Foundation", "#B5ACA0");
            Box(house, "Wall Plaster", new Vector3(0, height * .5f + .48f, 0),
                new Vector3(width, height, depth), "Plaster", plaster);
            var left = Box(house, "Gabled Roof Left",
                new Vector3(-width * .24f, height + 2f, 0),
                new Vector3(width * .61f, .7f, depth + 2.5f),
                "Roof", roofing);
            left.transform.localRotation = Quaternion.Euler(0f, 0f, 27f);
            var right = Box(house, "Gabled Roof Right",
                new Vector3(width * .24f, height + 2f, 0),
                new Vector3(width * .61f, .7f, depth + 2.5f),
                "Roof", roofing);
            right.transform.localRotation = Quaternion.Euler(0f, 0f, -27f);
            Box(house, "Wooden Door", new Vector3(0, 1.9f, -depth * .5f - .09f),
                new Vector3(2.5f, 3.7f, .24f), "Wood", "#77543B", false);
            foreach (float side in new[] { -1f, 1f })
            {
                Box(house, "Front Timber Beam", new Vector3(
                    side * (width * .5f - .25f), height * .5f + .4f,
                    -depth * .5f - .12f), new Vector3(.52f, height, .35f),
                    "Wood", "#77543B", false);
                Box(house, "Front Window", new Vector3(
                    side * width * .28f, height * .53f,
                    -depth * .5f - .14f), new Vector3(2.2f, 2.5f, .12f),
                    "Window", "#739CA5", false);
            }
        }

        private static void MarketStalls(Transform parent, Vector3 position)
        {
            var stalls = Group(parent, "Gate Market Stalls");
            stalls.localPosition = position;
            for (int i = 0; i < 3; i++)
            {
                float x = (i - 1) * 11f;
                Box(stalls, "Stall Counter " + i, new Vector3(x, 1.4f, 0f),
                    new Vector3(7f, 1.1f, 3.2f), "Wood", "#77543B");
                Box(stalls, "Colored Market Canopy " + i,
                    new Vector3(x, 4.7f, 0f), new Vector3(8.6f, .3f, 5.2f),
                    "Awning", "#9E6856", false);
            }
        }

        private static void Fountain(Transform parent, Vector3 position)
        {
            var fountain = Group(parent, "Town Center Fountain");
            fountain.localPosition = position;
            Cylinder(fountain, "Fountain Stone Plinth",
                new Vector3(0f, .65f, 0f), new Vector3(6.1f, .62f, 6.1f),
                "Foundation", "#B5ACA0");
            Cylinder(fountain, "Fountain Basin",
                new Vector3(0f, 1.55f, 0f), new Vector3(5.2f, .46f, 5.2f),
                "Stone", "#898F95");
            Cylinder(fountain, "Still Blue Water Preview",
                new Vector3(0f, 2.04f, 0f), new Vector3(4.55f, .055f, 4.55f),
                "Water", "#6DACC3", false);
            Cylinder(fountain, "Fountain Spire",
                new Vector3(0f, 3.7f, 0f), new Vector3(.8f, 2.3f, .8f),
                "Foundation", "#B5ACA0");
        }

        private static void GuildPorch(Transform parent)
        {
            var porch = Group(parent, "Guild Town Hall Details and Entrance");
            porch.localPosition = Point(-22f, 96f);
            float front = -9.5f;
            Box(porch, "Guild Entry Step", new Vector3(0f, .26f, front - 1.55f),
                new Vector3(7.2f, .46f, 2.8f), "Foundation", "#B5ACA0", false);
            Box(porch, "Guild Reception Roof", new Vector3(0f, 7.4f, front - 2f),
                new Vector3(19f, .7f, 5.4f), "Roof", "#475C7D", false);
            foreach (float x in new[] { -8.2f, 8.2f })
                Box(porch, "Guild Porch Column", new Vector3(x, 3.6f, front - 3.9f),
                    new Vector3(.55f, 7.2f, .55f), "Wood", "#77543B", false);
            Box(porch, "Golden Guild Charter Crest",
                new Vector3(0f, 9.1f, front - .24f),
                new Vector3(3.6f, 3.6f, .25f), "Guild Gold", "#E5BC65", false);
        }

        private static void NoticeBoards(Transform parent)
        {
            var notices = Group(parent, "Town Guild Board and Registration");
            notices.localPosition = Point(5f, 83f);
            string[] labels = {
                "Quest and Contract Board",
                "Public Notices and Town Orders",
                "New Adventurer Registration"
            };
            for (int i = 0; i < labels.Length; i++)
            {
                float x = (i - 1) * 6f;
                Box(notices, labels[i], new Vector3(x, 2.6f, 0f),
                    new Vector3(4.4f, 3.2f, .35f), "Wood", "#77543B");
                Box(notices, labels[i] + " Parchment",
                    new Vector3(x, 2.6f, -.22f),
                    new Vector3(3.8f, 2.6f, .06f),
                    "Parchment", "#DAC59C", false);
            }
        }

        private static void TrainingYard(Transform parent)
        {
            var yard = Group(parent, "Combat Training Yard");
            yard.localPosition = Point(-77f, 76f);
            Box(yard, "Packed Practice Ground", new Vector3(0, .04f, 0),
                new Vector3(26f, .09f, 18f), "Road", "#B2A18A", false);
            for (int i = -1; i <= 1; i++)
            {
                Cylinder(yard, "Wooden Training Dummy", new Vector3(i * 7f, 1.65f, 0f),
                    new Vector3(.65f, 1.65f, .65f), "Wood", "#77543B");
                Box(yard, "Dummy Practice Arms", new Vector3(i * 7f, 2.5f, 0f),
                    new Vector3(3.2f, .3f, .3f), "Wood", "#77543B");
            }
        }

        private static void Tree(Transform parent, string name,
                                 float x, float z, float height, bool pine)
        {
            var tree = Group(parent, name);
            tree.localPosition = Point(x, z);
            Cylinder(tree, "Tree Trunk", new Vector3(0f, height * .31f, 0f),
                new Vector3(.46f, height * .31f, .46f),
                "Wood", "#77543B", false);
            if (pine)
            {
                for (int tier = 0; tier < 3; tier++)
                    Sphere(tree, "Pine Crown " + tier,
                        new Vector3(0f, height * (.53f + tier * .17f), 0f),
                        new Vector3(5.6f - tier * 1.3f, 4.6f - tier * .5f,
                                    5.6f - tier * 1.3f),
                        "Leaves", "#496D47", false);
            }
            else
                Sphere(tree, "Leaf Crown", new Vector3(0f, height * .80f, 0f),
                    new Vector3(6.4f, 6.2f, 6.3f),
                    "Leaves", "#496D47", false);
        }
    }
}
