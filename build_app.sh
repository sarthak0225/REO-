#!/bin/zsh
set -e

echo "=== Building REO macOS Assistant Application ==="

CONFIG="${1:-debug}"
echo "Building mode: $CONFIG"

APP_DIR="REO.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy App Icon resources
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "Resources/AppIcon_1024.png" ]; then
    cp "Resources/AppIcon_1024.png" "$RESOURCES_DIR/AppIcon.png"
fi

# Create Info.plist first so it can be embedded in Mach-O
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>REO</string>
    <key>CFBundleDisplayName</key>
    <string>REO</string>
    <key>CFBundleIdentifier</key>
    <string>com.reo.assistant</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>REO</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>REO requires microphone access for voice dictation and conversation.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>REO uses speech recognition to convert your spoken questions into text.</string>
    <key>NSScreenCaptureUsageDescription</key>
    <string>REO inspects screen context only when you explicitly ask what is on your screen.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>REO interacts with applications to perform requested tasks.</string>
</dict>
</plist>
EOF

# Build with embedded __info_plist section to guarantee TCC validation
swift build -c "$CONFIG" -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker "$CONTENTS_DIR/Info.plist"

# Copy executable
cp ".build/$CONFIG/REO" "$MACOS_DIR/REO"
chmod +x "$MACOS_DIR/REO"

# Clear extended attributes and codesign bundle with entitlements
xattr -cr "$APP_DIR" || true
codesign --force --deep --sign - --entitlements Entitlements.plist "$APP_DIR"

# Register bundle with LaunchServices
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DIR" || true

echo "✓ Successfully created and registered $APP_DIR"
