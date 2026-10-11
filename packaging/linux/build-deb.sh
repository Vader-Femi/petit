#!/usr/bin/env bash
# Builds a .deb from a Flutter Linux release bundle.
#
# Usage: packaging/linux/build-deb.sh <bundle-dir> <version> <output.deb>
#   bundle-dir  build/linux/x64/release/bundle  (output of `flutter build linux --release`)
#   version     the pubspec version, e.g. 1.0.25+25
#   output.deb  file to create, e.g. petit-linux-amd64.deb
#
# The app is installed to /opt/petit with a launcher at /usr/bin/petit, a
# desktop entry and an icon. Needs `dpkg-deb`; uses ImageMagick's `convert`
# for the icon when it is available.
set -euo pipefail

APP_ID="io.github.vader_femi.petit"
MAINTAINER="Vader-Femi <vader-femi@users.noreply.github.com>"

BUNDLE_DIR="${1:?usage: build-deb.sh <bundle-dir> <version> <output.deb>}"
VERSION="${2:?usage: build-deb.sh <bundle-dir> <version> <output.deb>}"
OUTPUT="${3:?usage: build-deb.sh <bundle-dir> <version> <output.deb>}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"

if [ ! -x "$BUNDLE_DIR/petit" ]; then
  echo "error: $BUNDLE_DIR/petit not found. Is this a Flutter Linux release bundle?" >&2
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
PKG="$STAGE/pkg"

install -d "$PKG/DEBIAN" \
  "$PKG/opt/petit" \
  "$PKG/usr/bin" \
  "$PKG/usr/share/applications" \
  "$PKG/usr/share/icons/hicolor/512x512/apps"

# The app itself (executable bits are kept).
cp -a "$BUNDLE_DIR/." "$PKG/opt/petit/"
find "$PKG/opt/petit" -type d -exec chmod 0755 {} +
ln -s /opt/petit/petit "$PKG/usr/bin/petit"

# Desktop entry and icon.
install -m 0644 "$HERE/$APP_ID.desktop" "$PKG/usr/share/applications/$APP_ID.desktop"
ICON_SRC="$ROOT/assets/images/app_logo.png"
ICON_DST="$PKG/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
if command -v convert >/dev/null 2>&1; then
  convert "$ICON_SRC" -resize 512x512 "$ICON_DST"
else
  cp "$ICON_SRC" "$ICON_DST"
fi
chmod 0644 "$ICON_DST"

INSTALLED_SIZE_KB="$(du -sk "$PKG" | cut -f1)"

cat > "$PKG/DEBIAN/control" <<CONTROL
Package: petit
Version: $VERSION
Section: graphics
Priority: optional
Architecture: amd64
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE_KB
Depends: libgtk-3-0 | libgtk-3-0t64, libjson-glib-1.0-0 | libjson-glib-1.0-0t64
Homepage: https://github.com/Vader-Femi/petit
Description: Petit, an image and video compressor
 Compress JPG, PNG, WebP and HEIC images and common video formats
 to save space and send them faster, without losing visible quality.
CONTROL

dpkg-deb --build --root-owner-group "$PKG" "$OUTPUT"
echo "Built $OUTPUT"
