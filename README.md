# DigiGame

## Builds and releases

Windows, Linux, macOS, and Android packages are built remotely with GitHub Actions. See [docs/releases.md](docs/releases.md) for versioning, repeatable builds, Android signing, and the official release process.

## Web game and city sandbox

The Web export has two entry points in the same Godot project:

- `index.html` (or the site root) opens the normal game.
- `sandbox.html` opens the isolated, playable city experiment directly. It uses
  the bundled native city PNGs and does not request a ZIP file.

For a pull request preview, `/pr-N/` opens the normal game and
`/pr-N/sandbox.html` opens the city. On the production site, the corresponding
entries are `/` and `/sandbox.html`. The sandbox preserves the normal main scene
and menus; it has not been connected to the game's regular navigation.

Locally, open `experiments/darkmoon_sandbox/DarkmoonSandbox.tscn` and press F6
to run the city. F5 still starts the normal game. The city composition is original,
and its 8×8 TileSet and reusable modules support authoring your own scenery
without importing the original source-map layouts. See the
[city asset kit guide](experiments/darkmoon_sandbox/README.md) for editing and
local validation.

## Screenshot 20-09-2023
  ### Features:
  <ul>
    <li>Random terrain generation</li>
    <li>Camera zoom with limits</li>
    <li>Player movement with smoothing</li>
  </ul>
    
  ![20230920_212905](https://github.com/EwertonMendes/DigiGame/assets/33728924/503fd85a-dd46-419c-a44a-eba4c56ab718)

## Screenshot 21-09-2023
  ### Features:
  <ul>
    <li>Fixed hovered tile position</li>
    <li>Fixed digimon position on tile</li>
    <li>Added digimon animation</li>
    <li>Added background</li>
  </ul>
  
  ![20230921_230136](https://github.com/EwertonMendes/DigiGame/assets/33728924/8d2184eb-27ed-493d-bd3b-e4b74deae59a)

## Screenshot 24-09-2023
  ### Features:
  <ul>
    <li>Added particle effect when digimon is selected</li>
    <li>Added support for multiple digimons on the field</li>
  </ul>
  
  ![24092023](https://github.com/EwertonMendes/DigiGame/assets/33728924/ceff32fc-b124-461f-829b-f3ee8239af74)

  ## Screenshot 16-10-2023
  ### Features:
  <ul>
    <li>Added animation for multiple digimon on selecting it</li>
    <li>Fixed particle position offset</li>
    <li>Fixed bug on selecting digimon</li>
    <li>Made field smaller</li>
    <li>Changed initial zoom</li>
  </ul>

https://github.com/EwertonMendes/DigiGame/assets/33728924/a2fd34f0-ace6-4bc6-a9ce-cc2f5f02b0eb



