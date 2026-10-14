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
        static AetherfallProjectSetup()
        {
            EditorApplication.delayCall += EnsureScene;
        }

        [MenuItem("Aetherfall/Set Up Title and Login Scene")]
        public static void EnsureScene()
        {
            // Empty Unity scene: runtime UI is built on launch. This avoids brittle scene GUIDs.
            if (!File.Exists(ScenePath))
            {
                if (!Directory.Exists("Assets/Scenes")) Directory.CreateDirectory("Assets/Scenes");
                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                EditorSceneManager.SaveScene(scene, ScenePath);
                Debug.Log("Aetherfall: created startup scene at " + ScenePath);
            }
            var found = false;
            foreach (var scene in EditorBuildSettings.scenes)
                if (scene.path == ScenePath && scene.enabled) found = true;
            if (!found) EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
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
                scenes = new[] { ScenePath },
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
    /// Unity Cloud Build may use BuildPipeline directly, bypassing our
    /// custom editor menu. Re-apply PlayerSettings for every Android build.
    /// </summary>
    public sealed class AetherfallLandscapePrebuild : IPreprocessBuildWithReport
    {
        public int callbackOrder => -10000;

        public void OnPreprocessBuild(BuildReport report)
        {
            if (report.summary.platform != BuildTarget.Android) return;
            AetherfallProjectSetup.ConfigureLandscape();
            Debug.Log("Aetherfall Android orientation: locked to LandscapeLeft.");
        }
    }
}
#endif
