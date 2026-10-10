# Aetherfall Cleanroom Starter Town

Clean-room Android world prototype built around the verified Tripo/Mixamo player character.

Current source snapshot: Starter Town 0.3 / Visual Pass 2.

This branch intentionally does not reuse the old prototype world. The runtime character GLB is kept outside Git because the ChatGPT build pipeline currently injects the exact verified model bytes during APK assembly.

Current focus:
- stylized procedural town materials
- detailed timber/plaster building kit
- solid player collision and hard perimeter boundary
- third-person camera collision
- mobile joystick + tap-toggle sprint
- Android performance-oriented world construction
