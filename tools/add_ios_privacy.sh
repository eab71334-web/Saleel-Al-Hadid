#!/bin/bash
# Adds the iOS "Local Network" permission text to export_presets.cfg (needed for LAN play on iPhone).
# usage: bash tools/add_ios_privacy.sh export_presets.cfg
f="${1:-export_presets.cfg}"
python3 - "$f" <<'PY'
import re, sys
f = sys.argv[1]
s = open(f).read()
add = '<key>NSLocalNetworkUsageDescription</key><string>Medieval Wars uses the local network to find and join games on your Wi-Fi.</string>'
line = 'application/additional_plist_content="%s"' % add
out = []
done = False
for sec in re.split(r'(?m)^(?=\[preset\.\d+\])', s):
    if 'platform="iOS"' in sec and 'application/bundle_identifier' in sec:
        if 'application/additional_plist_content=' in sec:
            sec = re.sub(r'(?m)^application/additional_plist_content=.*$', lambda m: line, sec)
        else:
            sec = re.sub(r'(?m)^(application/bundle_identifier=.*)$', lambda m: m.group(1) + '\n' + line, sec, count=1)
        done = True
    out.append(sec)
open(f, 'w').write(''.join(out))
print("iOS preset patched" if done else "no iOS preset found")
PY
