# Engine splash assets

Generates the art and sound the engine's splash card (`BGE.EngineSplashCard`) uses. The
shipped files live in `src/source/engine/splash/`.

| Script | Makes | Needs |
| --- | --- | --- |
| `make_splash.py [out]` | `bge_title_*`, `bge_cannon_*`, `bge_cannonball_*` (`hd` and `fhd` webp) and `bge_cannon_*.json` (frame rects, timings, ball spawn) | Pillow with WebP, numpy, scipy, the Montserrat variable font (`MONTSERRAT=/path/to/Montserrat[wght].ttf`) |
| `make_sound.py [out]` | `bge_startup.wav` (stereo 44.1kHz) and `bge_startup.json` (cue times) | numpy, scipy |
| `downmix.py in.wav out.wav` | the shipped mono 22.05kHz copy, about a quarter the size | Python 3.12 or older (`audioop`) |
| `preview.py`, `preview_av.py` | preview stills, an animated webp and an mp4 with sound, from `out/` | Pillow, ffmpeg |

All art is white on transparent, so the engine tints it when drawing. The layout numbers in
`bge_cannon_*.json` are copied into `src/source/engine/splash/EngineSplashArt.bs`, and the cue
times in `bge_startup.json` into its timeline, so update those if you regenerate.

The title is set in Montserrat (SIL Open Font License 1.1, `Montserrat-OFL.txt`). Only the
rendered images ship, not the font.
