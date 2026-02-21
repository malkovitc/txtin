#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RESOURCES_DIR="$PROJECT_ROOT/Resources"
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
BASE_PNG="$RESOURCES_DIR/AppIcon-1024.png"
ICNS_PATH="$RESOURCES_DIR/AppIcon.icns"

mkdir -p "$RESOURCES_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

/usr/bin/swift - "$BASE_PNG" <<'SWIFT'
import AppKit
import Foundation

let outputPath = CommandLine.arguments[1]
let size = 1024.0
let canvas = NSSize(width: size, height: size)
let image = NSImage(size: canvas)

image.lockFocus()
NSColor.clear.setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvas)).fill()

let cardInset = 86.0
let cardRect = NSRect(
    x: cardInset,
    y: cardInset,
    width: size - cardInset * 2,
    height: size - cardInset * 2
)
let card = NSBezierPath(
    roundedRect: cardRect,
    xRadius: 150,
    yRadius: 150
)
NSColor.black.setFill()
card.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 210, weight: .regular),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]

let text = "txtin"
let textSize = text.size(withAttributes: attrs)
let rect = NSRect(
    x: cardRect.midX - textSize.width / 2.0,
    y: cardRect.midY - textSize.height / 2.0 + 8.0,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: rect, withAttributes: attrs)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to generate icon PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

cp "$BASE_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
cp "$BASE_PNG" "$ICONSET_DIR/icon_1024x1024.png"

/usr/bin/sips -z 16 16 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
/usr/bin/sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
/usr/bin/sips -z 32 32 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
/usr/bin/sips -z 64 64 "$BASE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
/usr/bin/sips -z 128 128 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
/usr/bin/sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
/usr/bin/sips -z 256 256 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
/usr/bin/sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
/usr/bin/sips -z 512 512 "$BASE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null

if /usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"; then
  echo "Generated icon: $ICNS_PATH"
else
  echo "Warning: iconutil failed to create AppIcon.icns; continuing without updating icon." >&2
fi
