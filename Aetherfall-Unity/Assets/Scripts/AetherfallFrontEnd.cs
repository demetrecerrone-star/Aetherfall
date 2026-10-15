using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace Aetherfall.Frontend
{
    /// <summary>
    /// Self-contained Unity uGUI title/login prototype. Uses real, editable input fields.
    /// Artwork is image-backed placeholder material until the castle and actors become a 3D scene.
    /// It intentionally does not collect, persist, or transmit credentials.
    /// </summary>
    public sealed class AetherfallFrontEnd : MonoBehaviour
    {
        private const float TravelSeconds = 2.25f;
        private Canvas canvas;
        private RectTransform titleArt, gateArt, loginPanel, safeRoot;
        private Image titleImage, gateImage;
        private CanvasGroup panelGroup;
        private Button titleTap;
        private InputField email, password;
        private Text status;
        private GameObject dialog;
        private Font uiFont;
        private bool atLogin, inTransition;
        private Vector2 previousSafeSize;
        private readonly List<RectTransform> motes = new List<RectTransform>();
        private readonly List<float> moteOffsets = new List<float>();
        private Sprite decorativeMote;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void Launch()
        {
            // The separately packaged town-preview APK launches into StarterTown.
            // Never cover its 3D camera with the production title/login overlay.
            if (SceneManager.GetActiveScene().name == "StarterTown") return;
            if (FindFirstObjectByType<AetherfallFrontEnd>() != null) return;
            var root = new GameObject("Aetherfall Front End");
            root.AddComponent<AetherfallFrontEnd>();
        }

        private void Awake()
        {
            Application.targetFrameRate = 60;
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            uiFont = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            BuildUI();
        }

        private void Update()
        {
            if (canvas == null) return;
            if (previousSafeSize != new Vector2(Screen.width, Screen.height)) UpdateSafeArea();
            float time = Time.unscaledTime;
            for (int i = 0; i < motes.Count; i++)
            {
                float q = time * (0.25f + i * 0.013f) + moteOffsets[i];
                motes[i].anchoredPosition = new Vector2(Mathf.Sin(q * 0.42f) * 22f, (q * 24f) % 1100f - 550f);
            }
            if (!inTransition && !atLogin && titleArt != null)
            {
                // Subtle perspective breathing: decorative 2.5D mock-up, not a 3D world claim.
                titleArt.anchoredPosition = new Vector2(Mathf.Sin(time * .18f) * 9f, Mathf.Cos(time * .16f) * 5f);
            }
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                if (dialog != null) CloseDialog();
                else if (atLogin && !inTransition) StartCoroutine(Travel(false));
            }
        }

        private void UpdateSafeArea()
        {
            previousSafeSize = new Vector2(Screen.width, Screen.height);
            if (Screen.width < 1 || Screen.height < 1) return;
            Rect r = Screen.safeArea;
            safeRoot.anchorMin = new Vector2(r.xMin / Screen.width, r.yMin / Screen.height);
            safeRoot.anchorMax = new Vector2(r.xMax / Screen.width, r.yMax / Screen.height);
            safeRoot.offsetMin = safeRoot.offsetMax = Vector2.zero;
        }

        private void BuildUI()
        {
            var canvasObject = new GameObject("Aetherfall UI", typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvasObject.transform.SetParent(transform, false);
            canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 100;
            CanvasScaler scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1600, 900);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0.5f;
            if (FindFirstObjectByType<EventSystem>() == null)
            {
                var events = new GameObject("EventSystem", typeof(EventSystem), typeof(StandaloneInputModule));
                events.transform.SetParent(transform, false);
            }

            // Full screen images deliberately separate from the safe-area controls.
            titleImage = MakeImage(canvas.transform, "Title Landscape", LoadSprite("TitleLandscape"), Color.white);
            titleArt = titleImage.rectTransform;
            Stretch(titleArt, Vector2.zero, Vector2.one);
            titleArt.pivot = new Vector2(.5f, .5f);
            gateImage = MakeImage(canvas.transform, "Castle Gate", LoadSprite("CastleGate"), new Color(1f, 1f, 1f, 0f));
            gateArt = gateImage.rectTransform;
            Stretch(gateArt, Vector2.zero, Vector2.one);
            gateArt.localScale = Vector3.one * 1.18f;
            titleImage.raycastTarget = gateImage.raycastTarget = false;

            var motesRoot = NewRect(canvas.transform, "Moving light motes");
            Stretch(motesRoot, Vector2.zero, Vector2.one);
            motesRoot.GetComponent<RectTransform>();
            decorativeMote = LoadSprite("Mote");
            System.Random rng = new System.Random(9147);
            for (int i = 0; i < 14; i++)
            {
                Image particle = MakeImage(motesRoot, "Mote " + i, decorativeMote,
                    new Color(1f, 0.94f, .79f, 0.11f + (float)rng.NextDouble() * .17f));
                var rt = particle.rectTransform;
                rt.anchorMin = rt.anchorMax = new Vector2((float)rng.NextDouble(), (float)rng.NextDouble());
                rt.sizeDelta = Vector2.one * (12f + (float)rng.NextDouble() * 24f);
                rt.anchoredPosition = Vector2.zero;
                particle.raycastTarget = false;
                motes.Add(rt);
                moteOffsets.Add((float)rng.NextDouble() * 25f);
            }

            safeRoot = NewRect(canvas.transform, "Safe Area UI");
            Stretch(safeRoot, Vector2.zero, Vector2.one);
            UpdateSafeArea();

            // The title art already contains the logo and TAP TO BEGIN typography.
            // This is a transparent clickable layer over the entire title, not a fake button.
            titleTap = MakeButton(safeRoot, "Tap anywhere to begin", "", Color.clear, Color.clear);
            Stretch(titleTap.GetComponent<RectTransform>(), Vector2.zero, Vector2.one);
            titleTap.onClick.AddListener(() => { if (!inTransition && !atLogin) StartCoroutine(Travel(true)); });

            Image panelImage = MakeImage(safeRoot, "Login Panel", LoadSprite("LoginPanel"), Color.white);
            loginPanel = panelImage.rectTransform;
            Stretch(loginPanel, new Vector2(.708f, .067f), new Vector2(.978f, .915f));
            panelGroup = loginPanel.gameObject.AddComponent<CanvasGroup>();
            panelGroup.alpha = 0;
            panelGroup.interactable = panelGroup.blocksRaycasts = false;
            PopulatePanel(loginPanel);
        }

        private void PopulatePanel(RectTransform parent)
        {
            var ivory = Hex("E8EDF8");
            var secondary = Hex("BDCDDF");
            var gold = Hex("EBC889");
            MakeText(parent, "Welcome", "Welcome to", 23, secondary, new Vector2(.1f, .815f), new Vector2(.9f, .867f), TextAnchor.MiddleCenter);
            MakeText(parent, "Name", "AETHERFALL", 41, ivory, new Vector2(.04f, .703f), new Vector2(.96f, .818f), TextAnchor.MiddleCenter);
            var line = MakeImage(parent, "Gold line", null, new Color(.84f, .7f, .44f, .85f));
            Stretch(line.rectTransform, new Vector2(.18f, .692f), new Vector2(.82f, .695f));

            email = MakeField(parent, "Email or Username", "IconMail", new Vector2(.075f, .564f), new Vector2(.925f, .641f), false);
            password = MakeField(parent, "Password", "IconLock", new Vector2(.075f, .457f), new Vector2(.925f, .534f), true);
            Button reveal = MakeButton(password.transform, "Show password", "", Color.clear, Color.clear);
            Stretch(reveal.GetComponent<RectTransform>(), new Vector2(.84f, 0), new Vector2(1, 1));
            Image eyeIcon = MakeImage(reveal.transform, "Visibility", LoadSprite("IconEye"), Color.white);
            Stretch(eyeIcon.rectTransform, new Vector2(.22f, .2f), new Vector2(.78f, .8f));
            eyeIcon.raycastTarget = false;
            reveal.onClick.AddListener(() =>
            {
                password.contentType = password.contentType == InputField.ContentType.Password
                    ? InputField.ContentType.Standard : InputField.ContentType.Password;
                password.ForceLabelUpdate();
            });

            var submit = MakeButton(parent, "Log In", "Log In", Hex("1E67B4"), gold);
            Stretch(submit.GetComponent<RectTransform>(), new Vector2(.074f, .345f), new Vector2(.926f, .434f));
            submit.GetComponentInChildren<Text>().fontSize = 28;
            submit.onClick.AddListener(TryLogin);

            MakeText(parent, "or", "—   or   —", 19, secondary,
                new Vector2(.15f, .303f), new Vector2(.85f, .339f), TextAnchor.MiddleCenter);

            var create = MakeButton(parent, "Create Account", "Create Account", Hex("152943"), gold);
            Stretch(create.GetComponent<RectTransform>(), new Vector2(.075f, .219f), new Vector2(.925f, .291f));
            create.GetComponentInChildren<Text>().color = gold;
            create.onClick.AddListener(() => OpenDialog("Create Account", "Account registration is the next development milestone. This preview does not save passwords or create accounts."));

            var google = MakeButton(parent, "Google Login", "Google Login", Hex("233957"), Hex("98AFCE"));
            Image googleIcon = MakeImage(google.transform, "Google Symbol", LoadSprite("IconGoogle"), Color.white);
            Stretch(googleIcon.rectTransform, new Vector2(.20f, .17f), new Vector2(.29f, .83f));
            googleIcon.raycastTarget = false;
            Text googleText = google.GetComponentInChildren<Text>();
            Stretch(googleText.rectTransform, new Vector2(.26f, 0), new Vector2(.98f, 1));
            Stretch(google.GetComponent<RectTransform>(), new Vector2(.075f, .127f), new Vector2(.925f, .198f));
            google.onClick.AddListener(() => OpenDialog("Google Login", "Google sign-in will be enabled after connecting a real authentication provider and configuring the Android app credentials."));

            var settings = MakeButton(parent, "Settings", "Settings", Color.clear, Color.clear);
            Stretch(settings.GetComponent<RectTransform>(), new Vector2(.19f, .049f), new Vector2(.81f, .111f));
            settings.onClick.AddListener(() => OpenDialog("Settings", "Aetherfall Unity Reboot — title/login UI preview.\n\nMusic, accessibility and network settings will be added to this menu."));

            status = MakeText(parent, "Validation status", "", 15, Hex("FFCC9E"),
                new Vector2(.055f, .005f), new Vector2(.945f, .055f), TextAnchor.MiddleCenter);
        }

        private void TryLogin()
        {
            if (string.IsNullOrWhiteSpace(email.text) || string.IsNullOrEmpty(password.text))
            {
                status.text = "Enter an email and password.";
                return;
            }
            // Do not authenticate against mock data or store secrets in PlayerPrefs.
            status.text = "";
            OpenDialog("Sign-in not connected", "The visual login screen is ready. Real authentication is not configured yet, so no credentials have been sent or saved.");
        }

        private void OpenDialog(string heading, string message)
        {
            CloseDialog();
            dialog = NewRect(safeRoot, "Dialog").gameObject;
            RectTransform cover = (RectTransform)dialog.transform;
            Stretch(cover, Vector2.zero, Vector2.one);
            MakeImage(cover, "Dimming", null, new Color(.02f, .045f, .09f, .72f));
            // Child dim needs to be stretched to the full safe area.
            RectTransform dim = (RectTransform)cover.GetChild(0);
            Stretch(dim, Vector2.zero, Vector2.one);
            Image dialogPane = MakeImage(cover, "Modal Panel", null, Hex("182C4A"));
            Stretch(dialogPane.rectTransform, new Vector2(.30f, .29f), new Vector2(.70f, .71f));
            dialogPane.gameObject.AddComponent<Outline>().effectColor = Hex("D2B678");
            MakeText(dialogPane.transform, "Heading", heading, 31, Hex("F8E6BA"),
                new Vector2(.06f, .72f), new Vector2(.94f, .94f), TextAnchor.MiddleCenter);
            Text body = MakeText(dialogPane.transform, "Body", message, 20, Hex("DBE8F8"),
                new Vector2(.08f, .27f), new Vector2(.92f, .72f), TextAnchor.MiddleCenter);
            body.horizontalOverflow = HorizontalWrapMode.Wrap;
            var close = MakeButton(dialogPane.transform, "Close", "Close", Hex("215991"), Hex("C9AD76"));
            Stretch(close.GetComponent<RectTransform>(), new Vector2(.33f, .065f), new Vector2(.67f, .24f));
            close.onClick.AddListener(CloseDialog);
        }

        private void CloseDialog()
        {
            if (dialog != null) Destroy(dialog);
            dialog = null;
        }

        private IEnumerator Travel(bool entering)
        {
            inTransition = true;
            titleTap.interactable = false;
            panelGroup.interactable = panelGroup.blocksRaycasts = false;
            float elapsed = 0f;
            while (elapsed < TravelSeconds)
            {
                elapsed += Time.unscaledDeltaTime;
                float normalized = Mathf.Clamp01(elapsed / TravelSeconds);
                float p = entering ? normalized : 1f - normalized;
                // Camera push/zoom combined with a scene overlap: no fade to black.
                float ease = p * p * (3f - 2f * p);
                titleArt.localScale = Vector3.one * Mathf.Lerp(1f, 2.02f, ease);
                titleArt.anchoredPosition = Vector2.Lerp(Vector2.zero, new Vector2(-410, -80), ease);
                gateArt.localScale = Vector3.one * Mathf.Lerp(1.18f, 1.0f, ease);
                gateArt.anchoredPosition = Vector2.Lerp(new Vector2(84, -30), Vector2.zero, ease);
                float blend = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(.28f, .79f, p));
                titleImage.color = new Color(1, 1, 1, 1f - blend);
                gateImage.color = new Color(1, 1, 1, blend);
                float reveal = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(.67f, .97f, p));
                panelGroup.alpha = reveal;
                loginPanel.anchoredPosition = new Vector2(Mathf.Lerp(70, 0, reveal), 0);
                yield return null;
            }
            atLogin = entering;
            titleArt.localScale = Vector3.one * (atLogin ? 2.02f : 1f);
            titleImage.color = new Color(1, 1, 1, atLogin ? 0f : 1f);
            gateImage.color = new Color(1, 1, 1, atLogin ? 1f : 0f);
            gateArt.localScale = Vector3.one * (atLogin ? 1f : 1.18f);
            panelGroup.alpha = atLogin ? 1f : 0f;
            panelGroup.interactable = panelGroup.blocksRaycasts = atLogin;
            loginPanel.anchoredPosition = Vector2.zero;
            titleTap.interactable = !atLogin;
            inTransition = false;
        }

        private InputField MakeField(Transform parent, string description, string iconSprite, Vector2 min, Vector2 max, bool secret)
        {
            var image = MakeImage(parent, description + " Input", null, Hex("142640"));
            Stretch(image.rectTransform, min, max);
            var border = image.gameObject.AddComponent<Outline>();
            border.effectColor = Hex("8099B9");
            border.effectDistance = Vector2.one;
            Image fieldIcon = MakeImage(image.transform, "Field Icon", LoadSprite(iconSprite), Color.white);
            Stretch(fieldIcon.rectTransform, new Vector2(.07f, .19f), new Vector2(.158f, .81f));
            fieldIcon.raycastTarget = false;
            var field = image.gameObject.AddComponent<InputField>();
            var contents = MakeText(image.transform, "Editable Text", "", 22, Color.white,
                new Vector2(.205f, .07f), new Vector2(secret ? .84f : .97f, .93f), TextAnchor.MiddleLeft);
            contents.supportRichText = false;
            field.textComponent = contents;
            field.placeholder = null; // Required: no placeholder words, real text appears here.
            field.characterLimit = secret ? 128 : 254;
            field.contentType = secret ? InputField.ContentType.Password : InputField.ContentType.EmailAddress;
            field.lineType = InputField.LineType.SingleLine;
            field.targetGraphic = image;
            field.selectionColor = new Color(.27f, .63f, .94f, .5f);
            field.onValueChanged.AddListener(_ => { if (status != null) status.text = ""; });
            return field;
        }

        private static Color Hex(string hex)
        {
            ColorUtility.TryParseHtmlString("#" + hex, out var color);
            return color;
        }

        private Sprite LoadSprite(string name)
        {
            Texture2D tex = Resources.Load<Texture2D>(name);
            if (tex == null)
            {
                Debug.LogError("Aetherfall: missing artwork Assets/Resources/" + name);
                return null;
            }
            return Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(.5f, .5f), 100f);
        }

        private static RectTransform NewRect(Transform parent, string name)
        {
            var obj = new GameObject(name, typeof(RectTransform));
            obj.transform.SetParent(parent, false);
            return (RectTransform)obj.transform;
        }

        private static void Stretch(RectTransform rect, Vector2 min, Vector2 max)
        {
            rect.anchorMin = min;
            rect.anchorMax = max;
            rect.offsetMin = rect.offsetMax = Vector2.zero;
            rect.localScale = Vector3.one;
        }

        private Image MakeImage(Transform parent, string name, Sprite sprite, Color tint)
        {
            var obj = new GameObject(name, typeof(RectTransform), typeof(Image));
            obj.transform.SetParent(parent, false);
            Image image = obj.GetComponent<Image>();
            image.sprite = sprite;
            image.color = tint;
            image.type = Image.Type.Simple;
            image.preserveAspect = false;
            return image;
        }

        private Text MakeText(Transform parent, string name, string message, int size, Color color, Vector2 min, Vector2 max, TextAnchor anchor)
        {
            var obj = new GameObject(name, typeof(RectTransform), typeof(Text));
            obj.transform.SetParent(parent, false);
            var rect = (RectTransform)obj.transform;
            Stretch(rect, min, max);
            Text text = obj.GetComponent<Text>();
            text.text = message;
            text.font = uiFont;
            text.fontSize = size;
            text.color = color;
            text.alignment = anchor;
            text.resizeTextForBestFit = true;
            text.resizeTextMinSize = Math.Max(11, size / 2);
            text.resizeTextMaxSize = size;
            text.raycastTarget = false;
            return text;
        }

        private Button MakeButton(Transform parent, string name, string message, Color bg, Color border)
        {
            Image image = MakeImage(parent, name, null, bg);
            if (border.a > .01f)
            {
                var outline = image.gameObject.AddComponent<Outline>();
                outline.effectColor = border;
                outline.effectDistance = new Vector2(1.8f, 1.8f);
            }
            Button button = image.gameObject.AddComponent<Button>();
            button.targetGraphic = image;
            ColorBlock cb = button.colors;
            cb.normalColor = Color.white;
            cb.highlightedColor = new Color(1.12f, 1.12f, 1.12f, 1f);
            cb.pressedColor = new Color(.8f, .85f, 1f, 1f);
            cb.selectedColor = Color.white;
            cb.fadeDuration = .08f;
            button.colors = cb;
            if (!string.IsNullOrEmpty(message))
                MakeText(button.transform, "Button Text", message, 23, Hex("EEF4FF"),
                    new Vector2(.02f, 0), new Vector2(.98f, 1), TextAnchor.MiddleCenter);
            return button;
        }
    }
}
