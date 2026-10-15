#if UNITY_EDITOR
using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace Aetherfall.Editor
{
    [InitializeOnLoad]
    public static class AetherfallProjectSetup
    {
        private const string ScenePath = "Assets/Scenes/AetherfallFrontEnd.unity";
        private const string TownScenePath = "Assets/Scenes/StarterTown.unity";
        static AetherfallProjectSetup()
        {
            EditorApplication.delayCall += EnsureScene;
        }

        [MenuItem("Aetherfall/Set Up Title and Login Scene")]
        public static void EnsureScene()
        {
            // Unity Cloud must bake the world during Editor import. A build containing
            // only the login scene is NOT a valid Aetherfall guest exploration build.
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
            {
                EditorApplication.delayCall += EnsureScene;
                return;
            }
            // Empty Unity startup scene: the title/login UI is built at runtime.
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath) == null)
            {
                if (!Directory.Exists("Assets/Scenes")) Directory.CreateDirectory("Assets/Scenes");
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                EditorSceneManager.SaveScene(scene, ScenePath);
                Debug.Log("Aetherfall: created startup scene at " + ScenePath);
            }
            // Generate the editable deterministic town once for a fresh Unity
            // Cloud checkout, then include it as scene 1 after the login scene.
            // This avoids relying on manually configured pre-export hooks.
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(TownScenePath) == null)
            {
                AetherfallWorldBuilder.GenerateStarterTown();
                AssetDatabase.ImportAsset(TownScenePath,
                    ImportAssetOptions.ForceSynchronousImport);
            }
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(TownScenePath) == null)
                throw new System.InvalidOperationException(
                    "Aetherfall guest world missing: unable to bake Assets/Scenes/StarterTown.unity.");

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(ScenePath, true),
                new EditorBuildSettingsScene(TownScenePath, true),
            };
            Debug.Log("AETHERFALL_GUEST_WORLD_READY: title + baked StarterTown included in build scenes.");
            PlayerSettings.productName = "Aetherfall";
            PlayerSettings.companyName = "Dabsky";
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, "com.demetrecerrone.aetherfall.unitydev");
            ConfigureLandscape();
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;
            EditorSettings.serializationMode = SerializationMode.ForceText;
        }

        /// <summary>
        /// Keep Android's launch Activity fixed in landscape, including the native
        /// splash screen (before any MonoBehaviour or video script can execute).
        /// Called during initial editor import and immediately before building.
        /// </summary>
        public static void ConfigureLandscape()
        {
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
        }

        [MenuItem("Aetherfall/Build Android Preview APK")]
        public static void BuildAndroidPreview()
        {
            EnsureScene();
            if (!EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Android, BuildTarget.Android))
                throw new System.Exception("Unable to select Android target. Install Unity Android Build Support, SDK/NDK and OpenJDK.");
            Directory.CreateDirectory("Builds");
            EditorUserBuildSettings.buildAppBundle = false;
            // Preview uses Unity's development signing; do not label as production/update-safe.
            var result = BuildPipeline.BuildPlayer(new BuildPlayerOptions
            {
                scenes = new[] { ScenePath, TownScenePath },
                locationPathName = "Builds/Aetherfall-Unity-Login-Preview.apk",
                target = BuildTarget.Android,
                options = BuildOptions.Development
            });
            if (result.summary.result != UnityEditor.Build.Reporting.BuildResult.Succeeded)
                throw new System.Exception("Aetherfall Android preview build failed: " + result.summary.result);
            Debug.Log("Aetherfall preview APK: Builds/Aetherfall-Unity-Login-Preview.apk");
        }
    }

    /// <summary>
    /// Optional Unity Build Automation Pre-Export Method:
    /// Aetherfall.Editor.AetherfallMainBuildPreExport.PreExport
    /// The Editor import path already prepares the scene without this hook.
    /// </summary>
    public static class AetherfallMainBuildPreExport
    {
        public static void PreExport()
        {
            AetherfallProjectSetup.EnsureScene();
        }
    }

    /// <summary>
    /// Unity Cloud Build may use BuildPipeline directly, bypassing our
    /// custom editor menu. Re-apply PlayerSettings for every Android build.
    /// </summary>
    public sealed class AetherfallLandscapePrebuild : IPreprocessBuildWithReport
    {
        public int callbackOrder => -10000;

        public void OnPreprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.Android) return;
            AetherfallProjectSetup.EnsureScene();
            AetherfallProjectSetup.ConfigureLandscape();
            Debug.Log("Aetherfall Android orientation: locked to LandscapeLeft; guest town verified.");
        }
    }
}
#endif
