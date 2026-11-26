Files the loading example downloads (they aren't in the channel package). By default it reads
them from this folder on GitHub's `main` branch. To serve them yourself:

    python3 -m http.server 8000 --directory examples/loading/remote-assets

then launch with `baseUrl=http://<your computer's IP>:8000/`. macOS may block incoming
connections to Python, so allow it when prompted, or use
`npx http-server examples/loading/remote-assets -p 8000` instead.

Credits: `fonts/Audiowide-Regular.ttf` is Audiowide by Astigmatic (SIL Open Font License, see
`fonts/OFL.txt`). `music/victory.mp3` is "Medieval: Victory Theme" by RandomMind (CC0,
https://opengameart.org/content/medieval-victory-theme). `images/icon.png` is the example's
own `Channel_Icon_HD.png`, generated for this repo by `scripts/generate-example-images.js`.
`images/rpgSplash.webp` is `examples/rpg`'s splash, "Broadsword" key art generated with Google
Gemini and supplied by the repo owner (see `examples/rpg/src/sprites/CREDITS.md`).
`models/d20.obj`, `models/d20.mtl` and `models/d20_atlas.png` are copies of `examples/3d`'s,
made for this repo (see `examples/3d/CREDITS.md`).

`maps/meadow.tmj` is a small Tiled map whose tileset (`maps/meadow.tsj`) is a separate file and
whose tileset image is `images/meadow-tiles.png`, so `loadTiledMap()` has to fetch all three
relative to the map's URL.
