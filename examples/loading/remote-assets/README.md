Files the loading example downloads (they aren't in the channel package). By default it reads
them from this folder on GitHub's `main` branch. To serve them yourself:

    python3 -m http.server 8000 --directory examples/loading/remote-assets

then launch with `baseUrl=http://<your computer's IP>:8000/`. macOS may block incoming
connections to Python, so allow it when prompted, or use
`npx http-server examples/loading/remote-assets -p 8000` instead.

Credits: `fonts/Audiowide-Regular.ttf` is Audiowide by Astigmatic (SIL Open Font License, see
`fonts/OFL.txt`). `music/victory.mp3` is "Medieval: Victory Theme" by RandomMind (CC0,
https://opengameart.org/content/medieval-victory-theme).
