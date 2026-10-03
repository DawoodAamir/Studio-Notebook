#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun simctl list devices available --json > build/simulators.json
simulator_id="${SIMULATOR_UDID:-$(python3 - <<'PYCODE'
import json
from pathlib import Path
for runtime, devices in json.loads(Path('build/simulators.json').read_text())['devices'].items():
    if 'iOS-27' in runtime:
        for device in devices:
            if device.get('isAvailable') and 'iPad' in device['name']:
                print(device['udid']); raise SystemExit
raise SystemExit('Install the iOS 27 runtime and create an iPad simulator in Xcode.')
PYCODE
)}"
xcrun simctl bootstatus "$simulator_id" -b
result="build/Workflow-$(date +%s).xcresult"
trap 'if [ -d "$result" ]; then xcrun xcresulttool export attachments --path "$result" --output-path build/Screenshots || true; fi' EXIT
xcodebuild -project 'Studio Notebook.xcodeproj' -scheme 'Studio Notebook' -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath build/DerivedData -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath "$result" test
