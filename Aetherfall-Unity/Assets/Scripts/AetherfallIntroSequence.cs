using System;
using System.Collections;
using System.IO;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;
using UnityEngine.Video;

namespace Aetherfall.Frontend
{
    /// <summary>
    /// Plays the provided Aetherfall cinematic one time before the title screen.
    /// Title and login visuals live in AetherfallFrontEnd behind this overlay.
    /// No account data is collected here.
    /// </summary>
    public sealed class AetherfallIntroSequence : MonoBehaviour
    {
        private const string MovieFile = "AetherfallIntro.mp4";
        private const float PrepareTimeoutSeconds = 9f;
        private const float MaximumPlaybackSeconds = 20f;
        private VideoPlayer player;
        private RawImage playbackSurface;
        private bool finished;
        private bool prepared;
        private float startedAt;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void ShowIntro()
        {
            if (FindFirstObjectByType<AetherfallIntroSequence>() != null)
                return;

            // In the Editor and on desktop, avoid covering the title if media
            // has not yet been uploaded. Android StreamingAssets lives in an APK
            // jar URL and cannot be checked using System.IO.File.Exists.
#if !UNITY_ANDROID || UNITY_EDITOR
            string localFile = Path.Combine(Application.streamingAssetsPath, MovieFile);
            if (!File.Exists(localFile))
            {
                Debug.LogWarning("Aetherfall: startup video not present; showing title screen.");
                return;
            }
#endif
            new GameObject("Aetherfall Opening Cinematic")
                .AddComponent<AetherfallIntroSequence>();
        }

        private void Awake()
        {
            startedAt = Time.unscaledTime;

            if (FindFirstObjectByType<EventSystem>() == null)
                new GameObject("Aetherfall Intro Event System",
                    typeof(EventSystem), typeof(StandaloneInputModule));

            var root = new GameObject("Opening Cinematic UI", typeof(RectTransform),
                typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            root.transform.SetParent(transform, false);
            var canvas = root.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 1000;
            var scaler = root.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1600, 900);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0.5f;

            var background = new GameObject("Black Video Background",
                typeof(RectTransform), typeof(Image));
            background.transform.SetParent(root.transform, false);
            var black = background.GetComponent<Image>();
            black.color = Color.black;
            FullScreen(black.rectTransform);

            var picture = new GameObject("Aetherfall Intro Video",
                typeof(RectTransform), typeof(RawImage));
            picture.transform.SetParent(root.transform, false);
            playbackSurface = picture.GetComponent<RawImage>();
            playbackSurface.color = Color.black;
            playbackSurface.raycastTarget = false;
            FullScreen(playbackSurface.rectTransform);

            var skip = new GameObject("Skip Intro", typeof(RectTransform),
                typeof(Image), typeof(Button));
            skip.transform.SetParent(root.transform, false);
            var skipRect = skip.GetComponent<RectTransform>();
            skipRect.anchorMin = skipRect.anchorMax = new Vector2(.94f, .94f);
            skipRect.pivot = new Vector2(1f, 1f);
            skipRect.sizeDelta = new Vector2(110f, 44f);
            skipRect.anchoredPosition = Vector2.zero;
            skip.GetComponent<Image>().color = new Color(.02f, .04f, .10f, .75f);
            skip.GetComponent<Button>().onClick.AddListener(FinishIntro);
            var text = new GameObject("Skip Label", typeof(RectTransform), typeof(Text));
            text.transform.SetParent(skip.transform, false);
            var label = text.GetComponent<Text>();
            label.text = "SKIP";
            label.font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            label.fontSize = 23;
            label.color = Color.white;
            label.alignment = TextAnchor.MiddleCenter;
            label.raycastTarget = false;
            FullScreen(label.rectTransform);

            player = gameObject.AddComponent<VideoPlayer>();
            player.playOnAwake = false;
            player.isLooping = false;
            player.waitForFirstFrame = true;
            player.skipOnDrop = true;
            player.source = VideoSource.Url;
            player.renderMode = VideoRenderMode.APIOnly;
            player.audioOutputMode = VideoAudioOutputMode.Direct;
            player.url = Application.streamingAssetsPath.TrimEnd('/') + "/" + MovieFile;
            player.prepareCompleted += VideoPrepared;
            player.loopPointReached += VideoFinished;
            player.errorReceived += VideoError;
            player.Prepare();
        }

        private static void FullScreen(RectTransform rect)
        {
            rect.anchorMin = Vector2.zero;
            rect.anchorMax = Vector2.one;
            rect.offsetMin = Vector2.zero;
            rect.offsetMax = Vector2.zero;
        }

        private void VideoPrepared(VideoPlayer video)
        {
            if (finished) return;
            prepared = true;
            if (video.texture != null)
            {
                playbackSurface.texture = video.texture;
                playbackSurface.color = Color.white;
            }
            video.Play();
            if (video.audioTrackCount > 0)
            {
                video.EnableAudioTrack(0, true);
                video.SetDirectAudioVolume(0, .75f);
            }
            StartCoroutine(WaitForVideoTexture(video));
        }

        private IEnumerator WaitForVideoTexture(VideoPlayer video)
        {
            float started = Time.unscaledTime;
            while (!finished && playbackSurface.texture == null &&
                   Time.unscaledTime - started < 4f)
            {
                if (video.texture != null)
                {
                    playbackSurface.texture = video.texture;
                    playbackSurface.color = Color.white;
                    break;
                }
                yield return null;
            }
        }

        private void VideoFinished(VideoPlayer video) => FinishIntro();

        private void VideoError(VideoPlayer video, string message)
        {
            Debug.LogWarning("Aetherfall startup cinematic could not play. Showing title instead.");
            FinishIntro();
        }

        private void Update()
        {
            if (finished) return;
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                FinishIntro();
                return;
            }
            float elapsed = Time.unscaledTime - startedAt;
            if ((!prepared && elapsed > PrepareTimeoutSeconds) ||
                (prepared && elapsed > MaximumPlaybackSeconds))
            {
                Debug.LogWarning("Aetherfall cinematic timed out; showing title.");
                FinishIntro();
            }
        }

        private void FinishIntro()
        {
            if (finished) return;
            finished = true;
            if (player != null)
            {
                player.prepareCompleted -= VideoPrepared;
                player.loopPointReached -= VideoFinished;
                player.errorReceived -= VideoError;
                player.Stop();
            }
            Destroy(gameObject); // Reveals the existing Aetherfall title screen.
        }
    }
}
