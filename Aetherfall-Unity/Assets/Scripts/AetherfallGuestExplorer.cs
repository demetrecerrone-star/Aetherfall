using System;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Aetherfall.Exploration
{
    /// <summary>
    /// Offline guest entry to the baked starter town, for Android QA.
    /// Temporary low-poly avatar, third-person follow camera, touch joystick,
    /// look swipe, and tap sprint. No network authentication or saved progress.
    /// </summary>
    public sealed class AetherfallGuestExplorer : MonoBehaviour
    {
        private CharacterController character;
        private Camera worldCamera;
        private GameObject avatar;
        private Transform avatarModel;
        private Vector2 joystick;
        private int movementFinger = -1;
        private int lookFinger = -1;
        private float lookYaw;
        private float lookPitch = 24f;
        private float verticalVelocity;
        private bool sprint;
        private bool exiting;
        private GUIStyle labelStyle;
        private GUIStyle buttonStyle;
        private GUIStyle joystickStyle;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void Register()
        {
            SceneManager.sceneLoaded -= OnSceneLoaded;
            SceneManager.sceneLoaded += OnSceneLoaded;
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void LaunchInitialScene()
        {
            OnSceneLoaded(SceneManager.GetActiveScene(), LoadSceneMode.Single);
        }

        private static void OnSceneLoaded(Scene scene, LoadSceneMode mode)
        {
            if (scene.name != "StarterTown") return;
            StartInTown();
        }

        // A SceneManager.CreateScene() fallback doesn't fire sceneLoaded; the
        // login flow calls this directly after creating its runtime town.
        public static void StartInTown()
        {
            if (SceneManager.GetActiveScene().name != "StarterTown") return;
            if (FindFirstObjectByType<AetherfallGuestExplorer>() != null) return;
            new GameObject("Guest Explorer - Offline Town Test")
                .AddComponent<AetherfallGuestExplorer>();
        }

        private void Awake()
        {
            Application.targetFrameRate = 30;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
#if UNITY_ANDROID && !UNITY_EDITOR
            Screen.autorotateToPortrait = false;
            Screen.autorotateToPortraitUpsideDown = false;
            Screen.autorotateToLandscapeLeft = true;
            Screen.autorotateToLandscapeRight = false;
            Screen.orientation = ScreenOrientation.LandscapeLeft;
#endif
            var marker = GameObject.Find("Player Spawn - Inside South Gate");
            Vector3 spawn = marker != null
                ? marker.transform.position - Vector3.up * .85f
                : new Vector3(0f, .15f, -93f);

            avatar = new GameObject("Guest - Temporary Adventurer");
            avatar.transform.position = spawn;
            // IgnoreRaycast keeps the follow camera from zooming into our own
            // avatar; physical CharacterController collisions remain enabled.
            avatar.layer = 2;
            character = avatar.AddComponent<CharacterController>();
            character.height = 2.5f;
            character.radius = .43f;
            character.center = new Vector3(0f, 1.25f, 0f);
            character.stepOffset = .34f;
            character.slopeLimit = 48f;
            avatarModel = new GameObject("Replace With Anime Character Model").transform;
            avatarModel.SetParent(avatar.transform, false);
            BuildSimpleAvatar();

            worldCamera = Camera.main;
            if (worldCamera == null)
            {
                GameObject cameraObject = new GameObject("Guest Third-Person Camera");
                worldCamera = cameraObject.AddComponent<Camera>();
                cameraObject.tag = "MainCamera";
            }
            worldCamera.orthographic = false;
            worldCamera.fieldOfView = 66f;
            worldCamera.farClipPlane = 650f;
            worldCamera.nearClipPlane = .12f;
            worldCamera.clearFlags = CameraClearFlags.SolidColor;
            worldCamera.backgroundColor = new Color(.68f, .79f, .91f);
            UpdateCamera(true);
        }

        private static Material SimpleMaterial(Color color)
        {
            // QA showed an all-magenta avatar, while the terrain and buildings
            // rendered correctly. A dynamically found shader may be stripped
            // from the Android player or incompatible with its active pipeline.
            // Copy a material which is ALREADY drawing in the current town.
            Material template = null;
            foreach (string name in new[] {
                "Walkable North Guild Hill", "Outer Meadow", "Outer Meadow Ground" })
            {
                GameObject source = GameObject.Find(name);
                if (source == null) continue;
                Renderer sourceRenderer = source.GetComponent<Renderer>();
                if (sourceRenderer == null || sourceRenderer.sharedMaterial == null)
                    continue;
                if (!sourceRenderer.sharedMaterial.shader.isSupported) continue;
                template = sourceRenderer.sharedMaterial;
                break;
            }

            Material material;
            if (template != null)
                material = new Material(template);
            else
            {
                // Only used if a future scene does not contain the expected
                // starter-terrain material. Choose the ACTIVE render pipeline.
                bool srp = UnityEngine.Rendering.GraphicsSettings.currentRenderPipeline != null;
                Shader shader = Shader.Find(srp
                    ? "Universal Render Pipeline/Lit" : "Standard");
                if (shader == null || !shader.isSupported)
                    shader = Shader.Find("Sprites/Default");
                if (shader == null || !shader.isSupported)
                {
                    Debug.LogError("AETHERFALL_GUEST_AVATAR_MATERIAL_FAILED: no supported shader.");
                    return null;
                }
                material = new Material(shader);
            }
            material.name = "Guest Avatar Color " + ColorUtility.ToHtmlStringRGB(color);
            if (material.HasProperty("_BaseColor"))
                material.SetColor("_BaseColor", color);
            if (material.HasProperty("_Color"))
                material.SetColor("_Color", color);
            if (material.HasProperty("_BaseMap"))
                material.SetTexture("_BaseMap", Texture2D.whiteTexture);
            if (material.HasProperty("_MainTex"))
                material.SetTexture("_MainTex", Texture2D.whiteTexture);
            material.color = color;
            return material;
        }

        private void AvatarPiece(string name, PrimitiveType shape,
            Vector3 position, Vector3 scale, Material material)
        {
            var piece = GameObject.CreatePrimitive(shape);
            piece.name = name;
            piece.layer = 2;
            piece.transform.SetParent(avatarModel, false);
            piece.transform.localPosition = position;
            piece.transform.localScale = scale;
            var collider = piece.GetComponent<Collider>();
            if (collider != null) Destroy(collider);
            var renderer = piece.GetComponent<Renderer>();
            if (renderer != null && material != null) renderer.sharedMaterial = material;
        }

        private void BuildSimpleAvatar()
        {
            // Clearly temporary: never misrepresent this as an approved anime model.
            var outfit = SimpleMaterial(new Color(.24f, .40f, .65f));
            var skin = SimpleMaterial(new Color(.96f, .76f, .57f));
            var hair = SimpleMaterial(new Color(.18f, .13f, .17f));
            var boots = SimpleMaterial(new Color(.21f, .17f, .18f));
            AvatarPiece("Blue Travel Tunic", PrimitiveType.Capsule,
                new Vector3(0f, 1.16f, 0f), new Vector3(.52f, .62f, .38f), outfit);
            AvatarPiece("Head", PrimitiveType.Sphere,
                new Vector3(0f, 2.06f, 0f), new Vector3(.68f, .74f, .65f), skin);
            AvatarPiece("Simple Dark Hair", PrimitiveType.Sphere,
                new Vector3(0f, 2.40f, -.09f), new Vector3(.73f, .27f, .73f), hair);
            foreach (float side in new[] { -1f, 1f })
            {
                AvatarPiece("Sleeve " + side, PrimitiveType.Capsule,
                    new Vector3(side * .43f, 1.30f, 0f),
                    new Vector3(.23f, .48f, .25f), outfit);
                AvatarPiece("Boot " + side, PrimitiveType.Capsule,
                    new Vector3(side * .20f, .34f, .02f),
                    new Vector3(.24f, .33f, .33f), boots);
            }
        }

        private Vector2 JoystickCenter()
        {
            Rect safe = Screen.safeArea;
            float offset = Mathf.Max(104f, safe.height * .20f);
            return new Vector2(safe.xMin + offset, safe.yMin + offset);
        }

        private void ReadTouchInput()
        {
            Vector2 baseCenter = JoystickCenter();
            float baseRadius = Mathf.Clamp(Screen.safeArea.height * .15f, 66f, 115f);
            foreach (Touch touch in Input.touches)
            {
                bool overJoystick = Vector2.Distance(touch.position, baseCenter) <=
                                    baseRadius * 1.5f;
                if (touch.phase == TouchPhase.Began)
                {
                    if (movementFinger < 0 && overJoystick &&
                        touch.position.x < Screen.width * .45f)
                        movementFinger = touch.fingerId;
                    else if (lookFinger < 0 && touch.position.x > Screen.width * .42f &&
                             touch.position.y < Screen.safeArea.yMax - 110f &&
                             touch.position.y > Screen.safeArea.yMin + 85f)
                        lookFinger = touch.fingerId;
                }

                if (touch.fingerId == movementFinger)
                {
                    if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
                    {
                        movementFinger = -1;
                        joystick = Vector2.zero;
                    }
                    else
                        joystick = Vector2.ClampMagnitude(
                            (touch.position - baseCenter) / baseRadius, 1f);
                }
                if (touch.fingerId == lookFinger)
                {
                    if (touch.phase == TouchPhase.Ended || touch.phase == TouchPhase.Canceled)
                        lookFinger = -1;
                    else if (touch.phase == TouchPhase.Moved)
                    {
                        lookYaw += touch.deltaPosition.x * .17f;
                        lookPitch = Mathf.Clamp(
                            lookPitch - touch.deltaPosition.y * .13f, 12f, 60f);
                    }
                }
            }
        }

        private void Update()
        {
            if (character == null || exiting) return;
            ReadTouchInput();

            Vector2 input = joystick;
            input.x = Mathf.Clamp(input.x + Input.GetAxisRaw("Horizontal"), -1f, 1f);
            input.y = Mathf.Clamp(input.y + Input.GetAxisRaw("Vertical"), -1f, 1f);
            input = Vector2.ClampMagnitude(input, 1f);

            // Camera-relative movement: the south-gate spawn faces toward the market.
            Quaternion direction = Quaternion.Euler(0f, lookYaw, 0f);
            Vector3 travel = direction * new Vector3(input.x, 0f, input.y);
            float speed = sprint ? 7.5f : 4.3f;
            if (character.isGrounded && verticalVelocity < 0f) verticalVelocity = -1f;
            verticalVelocity = Mathf.Max(-24f, verticalVelocity - 22f * Time.deltaTime);
            character.Move((travel * speed + Vector3.up * verticalVelocity)
                * Time.deltaTime);

            if (travel.sqrMagnitude > .005f)
                avatarModel.rotation = Quaternion.Slerp(avatarModel.rotation,
                    Quaternion.LookRotation(travel), Time.deltaTime * 10f);

            // Keep sprint a toggle, including when using the touch joystick.
            if (Input.GetKeyDown(KeyCode.LeftShift)) sprint = !sprint;
            UpdateCamera(false);
        }

        private void UpdateCamera(bool immediate)
        {
            if (worldCamera == null || avatar == null) return;
            Vector3 target = avatar.transform.position + Vector3.up * 1.65f;
            Quaternion orbit = Quaternion.Euler(lookPitch, lookYaw, 0f);
            Vector3 direction = -(orbit * Vector3.forward);
            float distance = 7.6f;
            RaycastHit obstruction;
            if (Physics.SphereCast(target, .20f, direction, out obstruction,
                                   distance, Physics.DefaultRaycastLayers,
                                   QueryTriggerInteraction.Ignore))
                distance = Mathf.Max(1f, obstruction.distance - .3f);
            Vector3 desiredPosition = target + direction * distance;
            worldCamera.transform.position = immediate
                ? desiredPosition
                : Vector3.Lerp(worldCamera.transform.position, desiredPosition,
                               Mathf.Clamp01(Time.deltaTime * 12f));
            worldCamera.transform.LookAt(target, Vector3.up);
        }

        private void PrepareStyles()
        {
            if (labelStyle != null) return;
            labelStyle = new GUIStyle(GUI.skin.label)
            {
                fontSize = Mathf.Clamp(Mathf.RoundToInt(Screen.height * .034f), 17, 30),
                fontStyle = FontStyle.Bold,
                alignment = TextAnchor.MiddleLeft,
                normal = { textColor = Color.white },
            };
            buttonStyle = new GUIStyle(GUI.skin.button)
            {
                fontSize = Mathf.Clamp(Mathf.RoundToInt(Screen.height * .031f), 17, 29),
                fontStyle = FontStyle.Bold,
            };
            joystickStyle = new GUIStyle(GUI.skin.box)
            {
                alignment = TextAnchor.MiddleCenter,
                fontSize = Mathf.Clamp(Mathf.RoundToInt(Screen.height * .045f), 22, 40),
                normal = { textColor = Color.white },
            };
        }

        private void OnGUI()
        {
            if (exiting || character == null) return;
            PrepareStyles();
            Rect safe = Screen.safeArea;
            float top = Screen.height - safe.yMax;
            float h = safe.height;
            float w = safe.width;
            float side = Mathf.Max(12f, h * .025f);
            float buttonHeight = Mathf.Clamp(h * .11f, 54f, 87f);

            GUI.Box(new Rect(safe.xMin, top, w, buttonHeight + side * 2f),
                GUIContent.none);
            GUI.Label(new Rect(safe.xMin + side, top + side,
                Mathf.Max(120f, w * .52f), buttonHeight),
                "AETHERFALL   •   Guest Explorer", labelStyle);

            float buttonW = Mathf.Clamp(w * .17f, 112f, 210f);
            if (GUI.Button(new Rect(safe.xMax - side - buttonW, top + side,
                                    buttonW, buttonHeight),
                           "EXIT", buttonStyle))
            {
                exiting = true;
                SceneManager.LoadScene("AetherfallFrontEnd");
            }
            float sprintX = safe.xMax - 2f * side - buttonW * 2f;
            if (GUI.Button(new Rect(sprintX, top + side, buttonW, buttonHeight),
                sprint ? "SPRINT ON" : "SPRINT", buttonStyle))
                sprint = !sprint;

            Vector2 joyCenter = JoystickCenter();
            float radius = Mathf.Clamp(h * .15f, 66f, 115f);
            Rect joyBackground = new Rect(joyCenter.x - radius,
                Screen.height - joyCenter.y - radius, radius * 2f, radius * 2f);
            GUI.Box(joyBackground, "MOVE", joystickStyle);
            float thumb = radius * .43f;
            GUI.Box(new Rect(joyBackground.center.x - thumb + joystick.x * radius * .60f,
                             joyBackground.center.y - thumb - joystick.y * radius * .60f,
                             thumb * 2f, thumb * 2f),
                    "●", joystickStyle);
            GUI.Label(new Rect(safe.xMax - Mathf.Min(w * .43f, 435f),
                top + h - buttonHeight - side,
                Mathf.Min(w * .41f, 435f), buttonHeight),
                "Swipe right side to look", labelStyle);
        }

        private void OnDestroy()
        {
            if (avatar != null) Destroy(avatar);
        }
    }
}
