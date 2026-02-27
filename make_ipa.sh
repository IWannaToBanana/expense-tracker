#!/bin/bash
# iOS App to IPA converter
# Usage: ./make_ipa.sh path/to/Runner.app

APP_PATH="$1"
OUTPUT_DIR="$(pwd)"

if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 <path_to_app>"
    exit 1
fi

APP_NAME=$(basename "$APP_PATH" .app)
IPA_NAME="$APP_NAME.ipa"
PAYLOAD_DIR="$OUTPUT_DIR/Payload"

mkdir -p "$PAYLOAD_DIR"
cp -r "$APP_PATH" "$PAYLOAD_DIR/"
zip -r "$OUTPUT_DIR/$IPA_NAME" Payload/
rm -rf "$PAYLOAD_DIR"

echo "Created: $OUTPUT_DIR/$IPA_NAME"
