APP="/Users/josh/Desktop/VTT 2026-06-04 13-25-32/VTT.app"
VERSION=1.0.18
OUT=~/Desktop/VTT-${VERSION}.dmg
ICON="$APP/Contents/Resources/AppIcon.icns"

create-dmg \
  --volname "VTT" \
  --volicon "$ICON" \
  --window-pos 200 120 \
  --window-size 560 340 \
  --icon-size 128 \
  --icon "VTT.app" 140 170 \
  --hide-extension "VTT.app" \
  --app-drop-link 420 170 \
  "$OUT" \
  "$APP"

echo "Done: $OUT"