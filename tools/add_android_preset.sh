#!/usr/bin/env bash
# Appends an "Android" export preset to export_presets.cfg (keeps your iOS preset untouched).
set -e
CFG="${1:-export_presets.cfg}"
touch "$CFG"
if grep -q 'platform="Android"' "$CFG"; then
  echo "Android preset already exists - leaving it as is."
  exit 0
fi
N=$(grep -cE '^\[preset\.[0-9]+\]$' "$CFG" || true)
[ -s "$CFG" ] && [ -n "$(tail -c1 "$CFG")" ] && echo >> "$CFG"
cat >> "$CFG" <<PRESET

[preset.$N]

name="Android"
platform="Android"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/MedievalWars.apk"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.$N.options]

gradle_build/use_gradle_build=false
architectures/armeabi-v7a=false
architectures/arm64-v8a=true
architectures/x86=false
architectures/x86_64=false
package/unique_name="com.towerwars.medievalwars"
package/name="Medieval Wars"
package/signed=true
screen/immersive_mode=true
PRESET
echo "Added Android preset as preset.$N"
