# Prototype overworld characters

The two compact runtime sheets in this directory were mechanically extracted from the character spritesheet supplied by the project owner for the initial overworld prototype.

Supplied source SHA-256: `c4e817d332592bceda6a0d13863966413527480a213b44a1766bba5d72393dde`

- `player_blond.png`: first blond character in the upper-left block.
- `battle_operator_purple.png`: purple-haired character directly below that block.
- Runtime layout: three 24×32 walking frames in each of four rows (`down_left`, `down_right`, `up_left`, `up_right`).
- The source poses are packed in 20-pixel-wide horizontal slots. Each pose is now repacked into its own centered 24×32 runtime cell with transparent side gutters, so Godot's `hframes = 3` slicing cannot mix pixels from adjacent poses or neighboring characters.

The source sheet identifies itself as ripped artwork from *Digimon World Dawn/Dusk*. These files are therefore restricted prototype material and are not represented as original or freely licensed assets. They must be reviewed or replaced before any public or commercial release. No additional proprietary character art was downloaded for this implementation.
