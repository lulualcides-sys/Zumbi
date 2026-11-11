# Soldier asset and animation licensing

This revision replaces the cartoon player mesh with an animated military soldier model. It is **not** an exact recreation of the character in the user-supplied video.

## Animated soldier
- **Original mesh:** "FREE [Military Soldier] RIGGED" by **BAMEN**, licensed **Creative Commons Attribution 4.0 (CC BY 4.0)**.
- Original model: https://sketchfab.com/3d-models/free-military-soldier-rigged-e9c56308a67d4a3db62e914fafa4d198
- Conversion/retargeted GLB redistribution: https://github.com/cktang88/3d-fps/tree/130ac2a5c856401ec36e7d35afcfefe40c5801f4/public/assets/models/characters/soldier.glb
- **Animations:** Quaternius Universal Animation Library 1 and 2 (CC0) and selected 100STYLE motions by Ian Mason, Sebastian Starke and Taku Komura (CC BY 4.0), as documented by the source repository.
- 100STYLE citation and download: https://zenodo.org/records/8127870
- Quaternius: https://quaternius.com/
- Licence text: https://creativecommons.org/licenses/by/4.0/

**Changes:** Imported and transformed into Godot 4 GL Compatibility, selected runtime animation states, combined with a separately mounted Quaternius CC0 rifle, and used in the user's standalone Zombie Outbreak prototype. No claims of new ownership over the model or its animation source.

## Distribution
`python3 tools/install_tactical_art.py` downloads a **pinned commit** and checks GLB format, limits size, inspects animations, and prints SHA-256. Import happens in GitHub Actions; the build embeds the asset for runtime use. Neither the build nor the model requires a paid AI account.

If this asset is removed, Godot falls back to the Quaternius CC0 starter character. The player should not ship with a missing model without triggering QA warnings.
