#!/bin/bash

# Configuration
APP_NAME="MiddleClicker"
SWIFT_SOURCE="MiddleClicker.swift"
DMG_NAME="${APP_NAME}_Installer.dmg"
STAGING_DIR="dmg_staging"

# Check if swift file exists
if [ ! -f "$SWIFT_SOURCE" ]; then
    echo "Error: $SWIFT_SOURCE not found in the current directory."
    exit 1
fi

echo "🚀 Starting Build Process for $APP_NAME..."

# 1. Clean up previous builds
rm -rf "${APP_NAME}.app"
rm -f "$DMG_NAME"
rm -rf "$STAGING_DIR"

# 2. Create App Bundle Directory Structure
echo "📂 Creating App Bundle Structure..."
mkdir -p "${APP_NAME}.app/Contents/MacOS"
mkdir -p "${APP_NAME}.app/Contents/Resources"

# 3. Compile the Swift Code into the App Bundle
echo "🔨 Compiling Swift Code..."
swiftc "$SWIFT_SOURCE" -o "${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ Compilation failed."
    exit 1
fi

# 4. Generate Info.plist
echo "📝 Generating Info.plist..."
cat > "${APP_NAME}.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.opensource.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 5. Ad-hoc Code Signing
echo "🔏 Signing the Application..."
codesign --force --deep --sign - "${APP_NAME}.app"

# 6. Prepare Staging Area (This adds the Applications Shortcut)
echo "🔗 Creating Applications shortcut..."
mkdir "$STAGING_DIR"
cp -r "${APP_NAME}.app" "$STAGING_DIR/"
# This command creates the shortcut to /Applications
ln -s /Applications "$STAGING_DIR/Applications"

# 7. Create the DMG (Disk Image)
echo "📦 Packaging into DMG..."
hdiutil create -volname "${APP_NAME}" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$STAGING_DIR"

echo ""
echo "✅ Build Complete!"
echo "------------------------------------------------------"
echo "You can now upload '$DMG_NAME' to your GitHub releases."
echo "Note: Users will see 'MiddleClicker' and an 'Applications' shortcut."
echo "They can drag the app onto the shortcut to install."
echo "------------------------------------------------------"
