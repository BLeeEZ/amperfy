#!/bin/bash
#
# Generates the light and dark app icon previews shown in
# Settings > Display > App Icon from the Icon Composer files (*.icon).
#
# For every AmperfyKit/Assets/<Name>.icon this writes
#   AmperfyKit/Assets/Assets.xcassets/<Name>Preview.imageset/
#     <Name>Preview@1x.png       (light, @1x)
#     <Name>Preview.png          (light, @2x)
#     <Name>Preview@3x.png       (light, @3x)
#     <Name>PreviewDark@1x.png   (dark, @1x)
#     <Name>PreviewDark.png      (dark, @2x)
#     <Name>PreviewDark@3x.png   (dark, @3x)
#     Contents.json
#
# Requires Xcode 26 (uses its bundled Icon Composer command line tool "ictool").
#
# Usage:
#   ./BuildTools/generateIconPreviews.sh                 # all icons
#   ./BuildTools/generateIconPreviews.sh AmperfyTeal ... # only the given icons
#
# Set ICTOOL=/path/to/ictool to use a specific ictool binary.

set -euo pipefail

# Preview size in points; rendered at @1x (60x60 px), @2x (120x120 px) and @3x (180x180 px)
PREVIEW_POINTS=60

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
icon_dir="$repo_root/AmperfyKit/Assets"
catalog_dir="$icon_dir/Assets.xcassets"

find_ictool() {
  if [ -n "${ICTOOL:-}" ]; then
    echo "$ICTOOL"
    return
  fi
  local candidates=(
    "$(xcode-select -p 2>/dev/null)/../Applications/Icon Composer.app/Contents/Executables/ictool"
    "/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"
    "/Applications/Icon Composer.app/Contents/Executables/ictool"
  )
  for candidate in "${candidates[@]}"; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return
    fi
  done
  find /Applications -maxdepth 6 -path '*Icon Composer.app/Contents/Executables/ictool' 2>/dev/null | head -1
}

ictool="$(find_ictool)"
if [ -z "$ictool" ] || [ ! -x "$ictool" ]; then
  echo "error: ictool not found. Install Xcode 26 or set ICTOOL=/path/to/ictool." >&2
  exit 1
fi
echo "Using ictool: $ictool"

export_rendition() {
  local icon="$1" rendition="$2" scale="$3" output="$4" log
  # ictool prints a JSON result ("{ }" on success); only show it on failure
  if ! log="$("$ictool" "$icon" \
    --export-image \
    --output-file "$output" \
    --platform iOS \
    --rendition "$rendition" \
    --width "$PREVIEW_POINTS" \
    --height "$PREVIEW_POINTS" \
    --scale "$scale" 2>&1)"; then
    echo "$log" >&2
    return 1
  fi
}

write_contents_json() {
  local imageset="$1" name="$2"
  cat >"$imageset/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "${name}Preview@1x.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "${name}PreviewDark@1x.png",
      "idiom" : "universal",
      "scale" : "1x"
    },
    {
      "filename" : "${name}Preview.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "${name}PreviewDark.png",
      "idiom" : "universal",
      "scale" : "2x"
    },
    {
      "filename" : "${name}Preview@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "${name}PreviewDark@3x.png",
      "idiom" : "universal",
      "scale" : "3x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

if [ "$#" -gt 0 ]; then
  icons=()
  for name in "$@"; do
    icons+=("$icon_dir/${name%.icon}.icon")
  done
else
  icons=("$icon_dir"/*.icon)
fi

failures=0
for icon in "${icons[@]}"; do
  name="$(basename "$icon" .icon)"
  if [ ! -d "$icon" ]; then
    echo "✗ $name: $icon not found" >&2
    failures=$((failures + 1))
    continue
  fi

  imageset="$catalog_dir/${name}Preview.imageset"
  mkdir -p "$imageset"

  if export_rendition "$icon" Default 1 "$imageset/${name}Preview@1x.png" &&
    export_rendition "$icon" Default 2 "$imageset/${name}Preview.png" &&
    export_rendition "$icon" Default 3 "$imageset/${name}Preview@3x.png" &&
    export_rendition "$icon" Dark 1 "$imageset/${name}PreviewDark@1x.png" &&
    export_rendition "$icon" Dark 2 "$imageset/${name}PreviewDark.png" &&
    export_rendition "$icon" Dark 3 "$imageset/${name}PreviewDark@3x.png"; then
    write_contents_json "$imageset" "$name"
    echo "✓ $name"
  else
    echo "✗ $name: ictool export failed" >&2
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  echo "$failures icon(s) failed." >&2
  exit 1
fi
echo "Done. Generated previews for ${#icons[@]} icon(s)."
