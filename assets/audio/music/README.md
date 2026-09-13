# DigiGame music assets

These runtime music files were supplied directly by the project owner on 2026-09-13 for use in DigiGame.

| Runtime file | Supplied source | Runtime use | Processing | SHA-256 |
| --- | --- | --- | --- | --- |
| `zone_1.ogg` | `Zone 1(1).mp3` | Terminal Commons / Testing Lab | Reduced to one recurring musical cycle (~94.426 s), then transcoded to stereo Ogg Vorbis at 32 kHz / ~48 kbps for Web-friendly looping. | `6d0a8cc256a1a99d04ee66d9736471752744fa5288613ebe20765f7b60cc2b4f` |
| `battle_1.ogg` | `Battle 1(1).wav` | Standard tactical battle | Reduced to one recurring musical cycle (~118.401 s), then transcoded to stereo Ogg Vorbis at 32 kHz / ~48 kbps for Web-friendly looping. | `b5d54c0ecf6d59316f6e07034a669c575987d0d3cc7ab5e51ce879fc13f4f870` |

## Provenance / rights

- Delivery method: direct user upload to the DigiGame project conversation.
- Author / publisher: not provided.
- Original source URL: not provided.
- License: not provided.
- Attribution requirement: unknown.

These files are treated as project-owner-provided material, not as autonomously sourced third-party assets. Before public or commercial redistribution, the project owner should confirm that the supplied recordings may legally be redistributed with the game.

## Runtime behavior

`MusicDirector` configures both streams for infinite looping at runtime and crossfades between them when the active scene requests a different track. Keeping one musical cycle instead of the longer supplied recordings avoids shipping repeated audio data in the Web build.
