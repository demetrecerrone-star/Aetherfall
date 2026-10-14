#if UNITY_EDITOR
using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.SceneManagement;

namespace Aetherfall.Editor
{
    /// <summary>
    /// Generates the editable StarterTown.unity scene and captures REAL Unity
    /// camera renders. Unlike a concept diagram, these show actual compiled
    /// geometry and materials in the Unity Editor.
    ///
    /// Requires a graphics-enabled Unity Editor (no -nographics). Designed to
    /// run via the menu, -executeMethod, or a licensed graphical CI runner.
    /// Never modifies the login startup scene / EditorBuildSettings.
    /// </summary>
    public static class AetherfallTownPreviewCapture
    {
        private const int Width = 1600;
        private const int Height = 900;

        [MenuItem("Aetherfall/World Builder/Generate Town + Capture Screenshots")]
        public static void GenerateAndCapture()
        {
            AetherfallWorldBuilder.GenerateStarterTown();
            CaptureCurrentTown();
        }

        /// <summary>
        /// Supported Unity CLI entry point:
        /// Unity -batchmode -quit -projectPath ... -executeMethod
        /// Aetherfall.Editor.AetherfallTownPreviewCapture.GenerateAndCapture
        /// Use an available GPU/graphics context (e.g. graphical editor session).
        /// </summary>
        [MenuItem("Aetherfall/World Builder/Capture Screenshots of Open Town")]
        public static void CaptureCurrentTown()
        {
            if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
                throw new InvalidOperationException(
                    "Town screenshots need an initialized graphics device. " +
                    "Remove -nographics and use a graphical Unity Editor runner.");

            var scene = SceneManager.GetActiveScene();
            if (!scene.IsValid() || !scene.isLoaded ||
                GameObject.Find("Town Guild Hall - Civic Government") == null ||
                GameObject.Find("Gate Market Loop Road") == null ||
                GameObject.Find("Walkable North Guild Hill") == null)
                throw new InvalidOperationException(
                    "StarterTown scene has not been generated or is missing landmarks. " +
                    "Run Generate Town + Capture Screenshots first.");

            string projectRoot = Directory.GetParent(Application.dataPath).FullName;
            string folder = Path.Combine(projectRoot, "Builds", "StarterTownPreview");
            Directory.CreateDirectory(folder);
            Debug.Log("Aetherfall town preview folder: " + folder);

            // Make sure the generated scene itself persists and remains editable.
            if (!EditorSceneManager.SaveScene(scene))
                throw new IOException("Unable to save the generated town scene.");

            var go = new GameObject("Temporary Town Screenshot Camera");
            var camera = go.AddComponent<Camera>();
            camera.enabled = false;
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(.68f, .78f, .91f);
            camera.nearClipPlane = .12f;
            camera.farClipPlane = 900f;
            camera.allowHDR = false;
            camera.fieldOfView = 65f;

            try
            {
                // Pure top-down north-up scene map, independent of concept art.
                camera.orthographic = true;
                camera.orthographicSize = 153f;
                go.transform.position = new Vector3(0f, 245f, -10f);
                go.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
                Capture(camera, folder, "01-overhead-real-unity.png");

                // The first player's eye-line as they enter the southern gate.
                camera.orthographic = false;
                PlaceCamera(go.transform, new Vector3(20f, 12f, -130f),
                    new Vector3(0f, 3f, -61f));
                Capture(camera, folder, "02-south-gate-market.png");

                // Ascending winding roads and residential neighborhood.
                PlaceCamera(go.transform, new Vector3(5f, 20f, -29f),
                    new Vector3(-34f, 6f, 53f));
                Capture(camera, folder, "03-winding-road-to-guild.png");

                // The hilltop guild-run town hall, civic signs and forecourt.
                PlaceCamera(go.transform, new Vector3(26f, 19f, 62f),
                    new Vector3(-22f, 11f, 96f));
                Capture(camera, folder, "04-guild-town-hall.png");

                // A view down from guild hill toward the entrance market.
                PlaceCamera(go.transform, new Vector3(-22f, 20f, 76f),
                    new Vector3(0f, 1f, -60f));
                Capture(camera, folder, "05-view-from-guild-hill.png");

                File.WriteAllText(Path.Combine(folder, "README.txt"),
                    "AETHERFALL — GENERATED UNITY TOWN PREVIEWS\n" +
                    "These screenshots are actual Unity Editor camera captures, " +
                    "not generative concept art.\n" +
                    "Town scene: Assets/Scenes/StarterTown.unity\n" +
                    "Preset: Assets/WorldBuilder/starter-town.json\n" +
                    "Graphics-enabled Unity Editor required.\n");
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(go);
            }

            AssetDatabase.SaveAssets();
            Debug.Log("Aetherfall: wrote 5 town preview screenshots to " + folder +
                      " (original login build settings untouched).");
        }

        private static void PlaceCamera(Transform transform, Vector3 from, Vector3 lookAt)
        {
            transform.position = from;
            transform.rotation = Quaternion.LookRotation(lookAt - from, Vector3.up);
        }

        private static void Capture(Camera camera, string folder, string filename)
        {
            RenderTexture target = RenderTexture.GetTemporary(
                Width, Height, 24, RenderTextureFormat.ARGB32);
            RenderTexture previous = RenderTexture.active;
            Texture2D pixels = null;
            try
            {
                camera.targetTexture = target;
                camera.Render();
                RenderTexture.active = target;
                pixels = new Texture2D(Width, Height, TextureFormat.RGB24, false);
                pixels.ReadPixels(new Rect(0, 0, Width, Height), 0, 0, false);
                pixels.Apply(false, false);
                byte[] png = pixels.EncodeToPNG();
                if (png == null || png.Length < 8192)
                    throw new IOException("Unity screenshot produced empty/invalid pixels: " +
                                          filename);
                string destination = Path.Combine(folder, filename);
                File.WriteAllBytes(destination, png);
                Debug.Log("Aetherfall screenshot: " + destination +
                          " (" + png.Length + " bytes)");
            }
            finally
            {
                camera.targetTexture = null;
                RenderTexture.active = previous;
                RenderTexture.ReleaseTemporary(target);
                if (pixels != null) UnityEngine.Object.DestroyImmediate(pixels);
            }
        }
    }
}
#endif
