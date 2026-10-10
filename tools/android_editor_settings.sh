#!/usr/bin/env bash
# Creates a debug keystore and tells headless Godot where the Android SDK / JDK / keystore are.
set -e
SDK="$1"; JDK="$2"; KS="$HOME/debug.keystore"
[ -f "$KS" ] || keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
  -keystore "$KS" -storepass android -dname "CN=Android Debug,O=Android,C=US" \
  -validity 9999 -deststoretype pkcs12
mkdir -p "$HOME/.config/godot"
for v in 4 4.3 4.4 4.5 4.6; do
  cat > "$HOME/.config/godot/editor_settings-$v.tres" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$SDK"
export/android/java_sdk_path = "$JDK"
export/android/debug_keystore = "$KS"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
SETTINGS
done
echo "Editor settings written."
