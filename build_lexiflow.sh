#!/bin/bash

APP_NAME="LexiFlow"
BUILD_DIR="build"
SOURCES="LexiFlow/Sources/*.swift"

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"

# Compile
echo "Compiling Swift sources..."
swiftc $SOURCES \
    -o "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME" \
    -target arm64-apple-macosx13.0 \
    -sdk $(xcrun --show-sdk-path) \
    -O

if [ $? -ne 0 ]; then
    echo "Compilation failed!"
    exit 1
fi

# Copy Resources
cp LexiFlow/Info.plist "$BUILD_DIR/$APP_NAME.app/Contents/"
if [ -f "LexiFlow/Resources/AppIcon.icns" ]; then
    cp "LexiFlow/Resources/AppIcon.icns" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/"
fi

# Code Sign (Ad-hoc to run locally on Apple Silicon)
echo "Signing app..."
codesign --force --deep --sign - "$BUILD_DIR/$APP_NAME.app"

echo "Build successful! App is at $BUILD_DIR/$APP_NAME.app"
