#!/bin/bash
set -e

APP_NAME="LexiFlow"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
SOURCES="LexiFlow/Sources/*.swift"
OUT_X86="$BUILD_DIR/$APP_NAME-x86_64"
OUT_ARM="$BUILD_DIR/$APP_NAME-arm64"

# Cleanup
echo "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Compile for x86_64
echo "Compiling for x86_64..."
swiftc $SOURCES \
    -o "$OUT_X86" \
    -target x86_64-apple-macosx13.0 \
    -sdk $(xcrun --show-sdk-path) \
    -O

# Compile for arm64
echo "Compiling for arm64..."
swiftc $SOURCES \
    -o "$OUT_ARM" \
    -target arm64-apple-macosx13.0 \
    -sdk $(xcrun --show-sdk-path) \
    -O

# Create Universal Binary
echo "Creating Universal Binary..."
lipo -create "$OUT_X86" "$OUT_ARM" -output "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Clean up temp binaries
rm "$OUT_X86" "$OUT_ARM"

# Copy Resources
echo "Copying resources..."
cp "LexiFlow/Info.plist" "$APP_BUNDLE/Contents/"
if [ -f "LexiFlow/Resources/AppIcon.icns" ]; then
    cp "LexiFlow/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Code Sign
echo "Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Build successful! Universal app is at $APP_BUNDLE"
