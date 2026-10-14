# Aetherfall UI implementation notes

- Scene: automatically generated empty `Assets/Scenes/AetherfallFrontEnd.unity` on first Unity Editor import. UI is constructed at runtime in `AetherfallFrontEnd.Launch`.
- Layer order: title landscape image -> castle gate image -> floating light motes -> safe-area transparent title button -> right login panel.
- Travel: 2.25-second camera-style push from title artwork toward castle; gate fades *in over the scene* while title gets enlarged; no black interstitial. UI panel slides in late in the move.
- Right login panel: custom PNG frame; Unity uGUI `InputField` contains editable text, no placeholder, mail/lock art retained, password eye toggles hidden/visible.
- Google button: UI integration only (no SDK, token exchange, network calls or fake account).
- Visual screenshots are **concept art**; they are not screenshots of a Unity Editor/Android runtime.
- Sources for imported models live in `Documentation/male.glb`, `Documentation/female.glb`, unmodified.
