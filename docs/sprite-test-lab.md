# Digimon Sprite Test Lab

The Hub's temporary **SPRITE TEST** tool is used to validate field sprites before merging them.

It automatically discovers packaged Digimon `.tres` resources through `ResourceLoader`, with a small fallback roster for platforms where directory enumeration is unavailable. This keeps the tool functional in exported Web builds while still allowing newly added resources to appear automatically in normal builds.

Use **PREV/NEXT** or the selector to change species, WASD/arrow keys or the four movement buttons to walk, **Q/E** to rotate facing, **R** to reset, and **Space** to toggle automatic patrol. The field is split into dark and light halves so transparency/background residue is easy to spot.

All visible control labels intentionally use ASCII text so the project's UI font cannot render unsupported directional glyphs as placeholder boxes.
