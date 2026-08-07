#!/bin/bash
set -euo pipefail
ScramJet="./ScramJet"
Cache="$ScramJet/RevisionCache.json"
URL="https://raw.githubusercontent.com/MercuryWorkshop/scramjet/refs/heads/legacy/package.json"
get_json_field() {
	local file="$1"
	local field="$2"
	node -e "
const fs = require('node:fs');
try {
    const data = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
    const value = data[process.argv[2]];
    process.stdout.write(value == null ? '' : String(value));
} catch {
    process.stdout.write('');
}
" "$file" "$field"
}
mkdir -p "$ScramJet"
if [[ -f "$Cache" ]]; then
	localVersion="$(get_json_field "$Cache" "installed")"
	if [[ -z "$localVersion" ]]; then
		localVersion="-1"
	fi
else
    localVersion="-1"
fi
remoteVersion="$(curl -fsSL "$URL" | node -e '
const fs = require("node:fs");
let input = "";
process.stdin.on("data", (chunk) => input += chunk);
process.stdin.on("end", () => {
    try {
        const parsed = JSON.parse(input);
        process.stdout.write(parsed.version ? String(parsed.version) : "");
    } catch {
        process.stdout.write("");
    }
});
')"
if [[ -z "$remoteVersion" || "$remoteVersion" == "null" ]]; then
    echo "Failed to resolve remote ScramJet version."
    exit 1
fi
if [ "$localVersion" != "-1" ] && [ ! -d "$ScramJet/node_modules" ]; then
    pnpm --dir "$ScramJet" install
fi
if [[ "$localVersion" != "$remoteVersion" ]]; then
    echo "Version mismatch or uninitialized, reinstalling ScramJet..."
    printf '{\n  "precheck": { "usingAny": false, "PORT": -1 },\n  "PORTInfo": {}\n}\n' > cache.json
    rm -rf "$ScramJet"
    git clone --recursive --branch legacy https://github.com/MercuryWorkshop/ScramJet.git "$ScramJet"
    printf '{\n  "installed": "%s"\n}\n' "$remoteVersion" > "$Cache"
    echo "Cloned ScramJet version $remoteVersion"
    bash scripts/ScramJetInstaller.sh
else
    echo "ScramJet is on the latest version ($localVersion)."
fi
