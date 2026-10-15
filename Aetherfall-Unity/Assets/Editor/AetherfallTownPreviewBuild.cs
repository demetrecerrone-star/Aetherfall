#if UNITY_EDITOR
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;

namespace Aetherfall.Editor
{
    /// <summary>
    /// Dedicated Unity Build Automation PRE-EXPORT method for a separate
    /// town-preview build target. Never use on the production login target.
    ///
    /// Build Automation configuration:
    /// - Git branch: world-builder-prototype
    /// - Unity project subfolder: Aetherfall-Unity
    /// - Pre-export method: Aetherfall.Editor.AetherfallTownPreviewBuild.PreExport
    /// - Android APK, separate config from aetherfall-android
    ///
    /// This runs AFTER scripts compile, BEFORE Unity exports the Android player.
    /// It creates a persistent deterministic town scene and selects ONLY that
    /// scene for the preview APK. Its application ID is distinct so both APKs
    /// can be installed on a phone simultaneously.
    /// </summary>
    public static class AetherfallTownPreviewBuild
    {
        public const string PreviewPackageId = "com.demetrecerrone.aetherfall.townpreview";
        private const string TownScene = "Assets/Scenes/StarterTown.unity";

        [MenuItem("Aetherfall/World Builder/Prepare Isolated Android Town Preview")]
        public static void PreExport()
        {
            AetherfallWorldBuilder.GenerateStarterTown();

            // Scene assets created during this Editor session may need a
            // synchronous import before the build profile resolves them.
            AssetDatabase.ImportAsset(TownScene, ImportAssetOptions.ForceSynchronousImport);
            if (AssetDatabase.LoadAssetAtPath<SceneAsset>(TownScene) == null)
                throw new System.InvalidOperationException(
                    "Town scene generation failed; refusing to export placeholder login scene.");

            PlayerSettings.productName = "Aetherfall Town Preview";
            PlayerSettings.companyName = "Dabsky";
            PlayerSettings.SetApplicationIdentifier(
                NamedBuildTarget.Android, PreviewPackageId);
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.allowedAutorotateToPortrait = false;
            PlayerSettings.allowedAutorotateToPortraitUpsideDown = false;
            PlayerSettings.allowedAutorotateToLandscapeRight = false;
            PlayerSettings.allowedAutorotateToLandscapeLeft = true;
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel26;

            EditorBuildSettings.scenes = new[]
            {
                new EditorBuildSettingsScene(TownScene, true)
            };
            AssetDatabase.SaveAssets();
            Debug.Log(
                "AETHERFALL TOWN PREVIEW READY: " + TownScene +
                " | Android package=" + PreviewPackageId +
                " | deterministic guild/market geometry baked in Unity Editor.");
        }
    }
}
#endif
