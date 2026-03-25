#!/bin/bash

PROJECT="CalendarTodo.xcodeproj"
SCHEME="CalendarTodo-iOS"
SIM_UDID="583B9FB8-505F-43B5-9ACD-77AB44750AF3"
BUNDLE_ID="com.taehee.calendartodo"
APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/CalendarTodo-afrtqcwbyusdpedxxxkdgcqnjvsj/Build/Products/Debug-iphonesimulator/CalendarTodo.app"

echo "🔨 Building..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$SIM_UDID" build 2>&1 | tail -3

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

echo "📲 Installing & launching..."
xcrun simctl boot "$SIM_UDID" 2>/dev/null
open -a Simulator
xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" 2>/dev/null
xcrun simctl install "$SIM_UDID" "$APP_PATH"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"

echo "✅ Done"
