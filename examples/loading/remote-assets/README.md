Files the loading example downloads (they aren't in the channel package). By default it reads
them from this folder on GitHub's `main` branch. To serve them yourself:

    python3 -m http.server 8000 --directory examples/loading/remote-assets

then launch with `baseUrl=http://<your computer's IP>:8000/`.
