#!/bin/bash
# Script to build sqlite-vec with Homebrew SQLite

# Navigate to sqlite-vec directory (adjust path as needed)
SQLITE_VEC_DIR="${1:-sqlite-vec}"

if [ ! -d "$SQLITE_VEC_DIR" ]; then
    echo "Error: sqlite-vec directory not found at: $SQLITE_VEC_DIR"
    echo "Usage: $0 [path-to-sqlite-vec]"
    exit 1
fi

cd "$SQLITE_VEC_DIR" || exit 1

# Set environment variables for Homebrew SQLite
export LDFLAGS="-L/usr/local/opt/sqlite/lib $LDFLAGS"
export CPPFLAGS="-I/usr/local/opt/sqlite/include $CPPFLAGS"
export PKG_CONFIG_PATH="/usr/local/opt/sqlite/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "Building sqlite-vec with Homebrew SQLite..."
echo "LDFLAGS: $LDFLAGS"
echo "CPPFLAGS: $CPPFLAGS"

# Build the loadable extension
make loadable
