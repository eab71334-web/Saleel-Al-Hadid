#!/usr/bin/env bash
# Appends an "Update" export preset (used only to build the light update.pck).
set -e
CFG="${1:-export_presets.cfg}"
touch "$CFG"
if grep -q 'name="Update"' "$CFG"; then
  echo "Update preset already exists."
  exit 0
fi
N=$(grep -cE '^\[preset\.[0-9]+\]$' "$CFG" || true)
[ -s "$CFG" ] && [ -n "$(tail -c1 "$CFG")" ] && echo >> "$CFG"
cat >> "$CFG" <<PRESET

[preset.$N]

name="Update"
platform="Linux"
runnable=false
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter="game/*.txt"
exclude_filter="export_presets.cfg, tools/*, .github/*, *.md"
export_path=""
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.$N.options]

binary_format/embed_pck=false
texture_format/s3tc_bptc=false
texture_format/etc2_astc=true
PRESET
echo "Added Update preset as preset.$N"
