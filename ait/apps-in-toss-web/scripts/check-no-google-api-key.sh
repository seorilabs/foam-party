#!/usr/bin/env bash
set -euo pipefail

package_path="${1:-foam-party.ait}"
if [[ ! -f "$package_path" ]]; then
  echo "AIT package not found: $package_path" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

# The AIT header adds bytes before the embedded zip, so unzip can warn while
# still extracting successfully.
unzip -qq "$package_path" -d "$tmp_dir" 2>/dev/null || true

pattern='AIza[0-9A-Za-z_-]{20,}|generativelanguage\.googleapis\.com|@firebase/ai|gemini-[0-9]|api[_-]?secret|VITE_GA4_MP_API_SECRET'
if rg -a -l -e "$pattern" "$tmp_dir" >/dev/null; then
  echo "Forbidden Google/Gemini API marker found in $package_path" >&2
  rg -a -l -e "$pattern" "$tmp_dir" | sed "s#^$tmp_dir/##" >&2
  exit 1
fi

echo "AIT package contains no Google/Gemini API key marker."
