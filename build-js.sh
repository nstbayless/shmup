#!/bin/bash
set -e

# Remove existing build directory
if [ -d docs ]
then
  rm -r docs/
fi

# Create .love file by zipping game assets
echo "Creating shmup.love..."
zip -9 -r shmup.love assets/ src/ main.lua conf.lua

# Build JavaScript version using love.js
# -c: compatibility mode
# -t: title of the game
echo "Building JavaScript version..."
love.js -c -t "Shmup" shmup.love docs/

echo ""
echo "Build complete! Output is in docs/"
echo "To test locally, run: cd docs && python3 -m http.server 8000"
echo "Then open http://localhost:8000 in your browser"
