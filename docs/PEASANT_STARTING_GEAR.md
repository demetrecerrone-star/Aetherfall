# Peasant starting clothes and tutorial gear progression

Both playable Universal Base characters now spawn wearing a **worn linen tunic**, **patched wool trousers**, **scuffed leather boots** and **plain leather belt**. They are starter clothing, not an armor set; initial armor unlock status is false. Clothing is generated as skinned geometry from the existing body mesh and bound to the **same 65-bone skeleton**, so it follows all authored animations without attaching stationary costume primitives. Skin, face, hands, original animations and underlying body mesh remain intact.

Runtime implementation: `cleanroom/peasant_gear.gd` and `PeasantGear.equip_default()` in `cleanroom/starter_town.gd`. Gear is automatically applied on initial spawn and male/female switch. No new UI or action buttons.

Planned tutorial itemization (not yet playable, intentionally): step 1 starts in peasant attire; a first town NPC / trainer grants appropriate leather or padded chest armor; a basic weapon comes from training; subsequent quests reward boots, bracers, and stronger armor. Actual quest, inventory, wearable armor meshes, stat rules and equipment persistence are **future work**. Do not represent these as implemented.

The first clothes are geometry layers fitted to the source body. Check actual phone renders at idle / sprint / both genders for seams and hand/skin clipping before treating this pass as visually approved.
