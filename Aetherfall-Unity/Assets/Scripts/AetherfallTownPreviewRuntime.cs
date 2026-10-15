using System;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Aetherfall.Preview
{
    /// <summary>
    /// Lightweight mobile-friendly camera tour of the REAL baked Unity scene.
    /// Shown only in StarterTown.unity. No auth, no network or gameplay claims.
    /// Five selectable viewpoints make layout review possible from an Android APK.
    /// The build uses a distinct package name, so it does not overwrite Aetherfall.
    /// </summary>
    public sealed class AetherfallTownPreviewRuntime : MonoBehaviour
    {
        private struct Viewpoint
        {
            public readonly string Label;
            public readonly Vector3 Position;
            public readonly Vector3 LookAt;
            public readonly bool Overhead;
            public Viewpoint(string label, Vector3 position, Vector3 lookAt,
                             bool overhead = false)
            {
                Label = label;
                Position = position;
                LookAt = lookAt;
                Overhead = overhead;
            }
        }

        private static readonly Viewpoint[] Views =
        {
            new Viewpoint("Town map", new Vector3(0f, 245f, -10f),
                          new Vector3(0f, 0f, -10f), true),
            new Viewpoint("South gate / market", new Vector3(20f, 12f, -130f),
                          new Vector3(0f, 3f, -61f)),
            new Viewpoint("Winding road / homes", new Vector3(5f, 20f, -29f),
                          new Vector3(-34f, 6f, 53f)),
            new Viewpoint("Guild hall / town hall", new Vector3(26f, 19f, 62f),
                          new Vector3(-22f, 11f, 96f)),
            new Viewpoint("Lookout over the town", new Vector3(-22f, 20f, 76f),
                          new Vector3(0f, 1f, -60f)),
        };

        private Camera cameraView;
        private int activeView = 1;
        private GUIStyle titleStyle;
        private GUIStyle hintStyle;
        private GUIStyle navStyle;
        private bool guideVisible = true;
        private Vector3 cameraLookAt;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Launch()
        {
            // Also blocks accidental preview overlay in the login scene.
            if (SceneManager.GetActiveScene().name != "StarterTown") return;
            if (FindFirstObjectByType<AetherfallTownPreviewRuntime>() != null) return;
            new GameObject("Aetherfall Town Android Tour")
                .AddComponent<AetherfallTownPreviewRuntime>();
        }

        private void Awake()
        {
            Application.targetFrameRate = 30; // A conservative mobile preview.
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
#if UNITY_ANDROID && !UNITY_EDITOR
            Screen.autorotateToPortrait = false;
            Screen.autorotateToPortraitUpsideDown = false;
            Screen.autorotateToLandscapeRight = false;
            Screen.autorotateToLandscapeLeft = true;
            Screen.orientation = ScreenOrientation.LandscapeLeft;
#endif
            cameraView = Camera.main;
            if (cameraView == null)
            {
                var cameraObject = new GameObject("Town Tour Camera");
                cameraView = cameraObject.AddComponent<Camera>();
                cameraView.tag = "MainCamera";
            }
            cameraView.clearFlags = CameraClearFlags.SolidColor;
            cameraView.backgroundColor = new Color(.67f, .79f, .92f);
            cameraView.nearClipPlane = .12f;
            cameraView.farClipPlane = 900f;
            cameraView.allowHDR = false;
            SelectView(1);
        }

        private void SelectView(int nextIndex)
        {
            activeView = (nextIndex % Views.Length + Views.Length) % Views.Length;
            var view = Views[activeView];
            cameraLookAt = view.LookAt;
            cameraView.orthographic = view.Overhead;
            cameraView.orthographicSize = 153f;
            cameraView.fieldOfView = 65f;
            cameraView.transform.position = view.Position;
            // Looking exactly downward makes forward/up vectors collinear.
            // Use a stable explicit north-up map rotation in overhead mode.
            if (view.Overhead)
                cameraView.transform.rotation = Quaternion.Euler(90f, 0f, 0f);
            else
                cameraView.transform.LookAt(cameraLookAt, Vector3.up);
        }

        private void Update()
        {
            if (cameraView == null) return;
            if (Input.GetKeyDown(KeyCode.RightArrow)) SelectView(activeView + 1);
            if (Input.GetKeyDown(KeyCode.LeftArrow)) SelectView(activeView - 1);
            if (Input.GetKeyDown(KeyCode.H)) guideVisible = !guideVisible;

            // Swiping above the lower navigation area allows a gentle orbit.
            // It never changes the saved world or the player's login settings.
            if (activeView == 0 || Input.touchCount == 0) return;
            Touch touch = Input.GetTouch(0);
            if (touch.phase != TouchPhase.Moved) return;
            Rect safe = Screen.safeArea;
            float controlBand = Mathf.Max(95f, safe.height * .16f);
            if (touch.position.y < safe.yMin + controlBand) return;

            float delta = touch.deltaPosition.x * .15f;
            cameraView.transform.RotateAround(cameraLookAt, Vector3.up, delta);
            cameraView.transform.LookAt(cameraLookAt, Vector3.up);
        }

        private void InitGUI()
        {
            if (titleStyle != null) return;
            titleStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = Mathf.Clamp(Mathf.RoundToInt(Screen.height * .041f), 20, 45),
                fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleLeft,
                normal = { textColor = Color.white }
            };
            hintStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = Mathf.Clamp(Mathf.RoundToInt(Screen.height * .029f), 15, 28),
                alignment = TextAnchor.MiddleLeft,
                normal = { textColor = new Color(.87f, .92f, 1f) }
            };
            navStyle = new GUIStyle(GUI.skin.button)
            {
                fontSize = Mathf.Clamp(Mathf.RoundToInt(Screen.height * .032f), 17, 32),
                fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleCenter
            };
        }

        private void OnGUI()
        {
            if (cameraView == null) return;
            InitGUI();

            Rect safe = Screen.safeArea;
            float left = safe.xMin;
            float top = Screen.height - safe.yMax;
            float width = safe.width;
            float height = safe.height;
            float margin = Mathf.Max(15f, height * .027f);
            float buttonH = Mathf.Clamp(height * .11f, 66f, 108f);
            float topBarH = Mathf.Clamp(height * .135f, 82f, 150f);

            GUI.Box(new Rect(left, top, width, topBarH), GUIContent.none);
            GUI.Label(new Rect(left + margin, top + 6f, width - 2f * margin,
                               topBarH * .53f),
                      "AETHERFALL  •  " + Views[activeView].Label, titleStyle);
            if (guideVisible)
                GUI.Label(new Rect(left + margin, top + topBarH * .53f,
                                   width - 2f * margin, topBarH * .39f),
                          "Unity town blockout • Swipe to orbit • Use arrows to tour",
                          hintStyle);

            float bottom = top + height - buttonH - margin;
            float arrowWidth = Mathf.Max(95f, width * .14f);
            if (GUI.Button(new Rect(left + margin, bottom, arrowWidth, buttonH),
                           "◀ PREV", navStyle))
                SelectView(activeView - 1);
            if (GUI.Button(new Rect(left + width - margin - arrowWidth,
                                    bottom, arrowWidth, buttonH),
                           "NEXT ▶", navStyle))
                SelectView(activeView + 1);

            Rect label = new Rect(left + margin + arrowWidth + 8f, bottom,
                                  width - (margin + arrowWidth + 8f) * 2f,
                                  buttonH);
            GUI.Box(label, (activeView + 1) + " / " + Views.Length +
                           "     " + Views[activeView].Label, navStyle);
        }
    }
}
