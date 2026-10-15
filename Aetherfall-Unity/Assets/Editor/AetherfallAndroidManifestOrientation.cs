#if UNITY_EDITOR
using System;
using System.IO;
using System.Xml;
using UnityEditor.Android;
using UnityEngine;

namespace Aetherfall.Editor
{
    /// <summary>
    /// Last-mile Android orientation enforcement for Unity 6 and Unity Cloud.
    ///
    /// PlayerSettings are set by AetherfallLandscapePrebuild, but an external
    /// build configuration can still generate the Android launch Activity with
    /// a different orientation. Modify Unity's generated Gradle manifests after
    /// generation (before Gradle merges them into the final APK). This avoids
    /// replacing Unity's entire manifest template and preserves GameActivity.
    /// </summary>
    public sealed class AetherfallAndroidManifestOrientation : IPostGenerateGradleAndroidProject
    {
        private const string AndroidNamespace = "http://schemas.android.com/apk/res/android";
        public int callbackOrder => 10000;

        public void OnPostGenerateGradleAndroidProject(string unityLibraryPath)
        {
            string libraryManifest = Path.Combine(
                unityLibraryPath, "src", "main", "AndroidManifest.xml");
            string parent = Directory.GetParent(unityLibraryPath).FullName;
            string launcherManifest = Path.Combine(
                parent, "launcher", "src", "main", "AndroidManifest.xml");

            if (!File.Exists(libraryManifest))
                throw new IOException(
                    "Aetherfall orientation verification failed: no Unity library AndroidManifest.xml at "
                    + libraryManifest);

            int unityActivities = 0;
            unityActivities += PatchManifest(libraryManifest);
            if (File.Exists(launcherManifest))
                unityActivities += PatchManifest(launcherManifest);

            if (unityActivities < 1)
                throw new InvalidOperationException(
                    "Aetherfall orientation verification failed: no Unity Player Activity or " +
                    "GameActivity found in the generated Gradle manifests. " +
                    "Refusing to produce an APK that may launch in portrait.");

            Debug.Log("AETHERFALL_ORIENTATION_VERIFY: patched " + unityActivities +
                      " Unity Android launch activity entries to landscape.");
        }

        private static int PatchManifest(string filePath)
        {
            var document = new XmlDocument { PreserveWhitespace = true, XmlResolver = null };
            document.Load(filePath);

            XmlNodeList activities = document.SelectNodes("/manifest/application/activity");
            if (activities == null) return 0;

            int patched = 0;
            foreach (XmlNode node in activities)
            {
                var activity = node as XmlElement;
                if (activity == null) continue;
                string activityName = activity.GetAttribute("name", AndroidNamespace);
                // Works with UnityPlayerActivity and UnityPlayerGameActivity.
                // Do not alter third-party SDK activities.
                bool unityPlayer = activityName.Contains("UnityPlayer") ||
                                   activityName.EndsWith("AppUIGameActivity", StringComparison.Ordinal);
                if (!unityPlayer) continue;

                XmlAttribute orientation = document.CreateAttribute(
                    "android", "screenOrientation", AndroidNamespace);
                orientation.Value = "landscape";
                activity.Attributes.SetNamedItem(orientation);
                patched++;
                Debug.Log("AETHERFALL_ORIENTATION_VERIFY: " + activityName +
                          " -> android:screenOrientation=landscape");
            }

            if (patched > 0)
                document.Save(filePath);
            return patched;
        }
    }
}
#endif
