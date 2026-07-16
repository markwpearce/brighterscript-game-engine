#!/bin/sh
# Scaffolds a new example app under examples/<name> from scripts/exampleTemplate.
#
# Usage: ./scripts/create_example.sh <name> ["Display Title"]
#   name  - directory name under examples/, e.g. "quickstart" -> examples/quickstart
#   title - optional manifest/display title, defaults to "Example Game - <name>"

set -e

NAME="$1"
if [ -z "$NAME" ]; then
  echo "Usage: ./scripts/create_example.sh <name> [\"Display Title\"]"
  exit 1
fi

TITLE="$2"
if [ -z "$TITLE" ]; then
  TITLE="Example Game - $NAME"
fi

DIR="examples/$NAME"

if [ -e "$DIR" ]; then
  echo "$DIR already exists, aborting."
  exit 1
fi

cp -R scripts/exampleTemplate "$DIR"
find "$DIR" -name ".gitkeep" -delete
find "$DIR" -name ".DS_Store" -delete

# Replace template placeholders in text files (manifest, launch.json)
if [ "$(uname)" = "Darwin" ]; then
  sed -i '' "s/__TITLE__/$TITLE/g" "$DIR/src/manifest" "$DIR/.vscode/launch.json"
else
  sed -i "s/__TITLE__/$TITLE/g" "$DIR/src/manifest" "$DIR/.vscode/launch.json"
fi

# Generate simple icon/splash images with the title on a plain background
# (same look as examples/rendererTest) using a pure-JS renderer - no
# ImageMagick or other native/system dependency required.
node "$(dirname "$0")/generate_example_images.js" "$TITLE" "$DIR/src/images"

# Add the new example to the root .vscode debug/build task picker
node "$(dirname "$0")/add_example_to_vscode_tasks.js" "$NAME"

echo "Created $DIR"
echo ""
echo "Next steps:"
echo "  cd $DIR && npm install"
echo "  # add entities under src/source/Entities, rooms under src/source/Rooms"
echo "  # add sprites/sounds/models under src/sprites, src/sounds, src/models"
echo "  npm run build"
