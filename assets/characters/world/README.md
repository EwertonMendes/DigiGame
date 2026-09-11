# Prototype overworld characters

The two compact runtime sheets in this directory were mechanically extracted from the character spritesheet supplied by the project owner for the initial overworld prototype.

Supplied source SHA-256: `c4e817d332592bceda6a0d13863966413527480a213b44a1766bba5d72393dde`

- `player_blond.png`: first blond character in the upper-left block.
- `battle_operator_purple.png`: purple-haired character directly below that block.
- Runtime layout: three 24×32 walking frames in each of five authored rows: `south` (0–2), `southwest` (3–5), `west` (6–8), `northwest` (9–11), `north` (12–14).
- The source sheet only draws one horizontal half of the eight directions. Runtime mirrors the `southwest`, `west`, and `northwest` rows horizontally to obtain `southeast`, `east`, and `northeast` without inventing or re-cropping poses.
- The walking cycle is `idle → step A → idle → step B`, using frame columns `0 → 1 → 0 → 2` inside the selected direction row.
- Each pose is isolated in its own 24×32 runtime cell with transparent side gutters so Godot's `hframes = 3` slicing cannot mix pixels from adjacent poses or neighboring characters.

The source sheet identifies itself as ripped artwork from *Digimon World Dawn/Dusk*. These files are therefore restricted prototype material and are not represented as original or freely licensed assets. They must be reviewed or replaced before any public or commercial release. No additional proprietary character art was downloaded for this implementation.
