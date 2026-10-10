# Starter Town Texture Library (CC0)

The seven albedo maps for the Starter Town mobile prototype come from **Poly Haven** and are public-domain-equivalent **CC0** assets suitable for commercial games.

The source JPEG/PNG files are not checked into Git. The reproducible downloader `../tools/fetch_town_textures.py` requests the official Poly Haven API, verifies the publisher's MD5 if present, scales diffuse maps to 512–1024 pixels, and saves JPEG bytes in `.bin` files for reliable Godot Android export.

| Runtime material | Poly Haven source |
|---|---|
| Cobblestone road | https://polyhaven.com/a/cobblestone_pavement |
| Grass ground | https://polyhaven.com/a/leafy_grass |
| Dirt shoulders | https://polyhaven.com/a/dirt |
| Plaster walls | https://polyhaven.com/a/plastered_wall |
| Wood beams / doors | https://polyhaven.com/a/wood_planks |
| Roof tile | https://polyhaven.com/a/roof_tiles |
| Stonework / fountain | https://polyhaven.com/a/stone_wall |

License: https://polyhaven.com/license (CC0, free for personal and commercial use). Attribution is not necessary for the asset files, but Poly Haven deserves credit. Aetherfall only uses the API **at build time**, never on a player's device.

**Source of truth:** `../tools/fetch_town_textures.py` and its generated `build-manifest.json`; the signed Android workflow refuses to ship if any raw diffuse map is missing from the exported game pack. The prior **v0.2R** is the known-good character/movement fallback.
