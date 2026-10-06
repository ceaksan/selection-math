#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
build_flags=(-c release --jobs 2 --arch arm64 --arch x86_64)
swift build "${build_flags[@]}"
binary_dir="$(swift build "${build_flags[@]}" --show-bin-path)"
app_dir="$project_dir/dist/SelectionMath.app"
/bin/rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
iconset_dir="$project_dir/.build/AppIcon.iconset"
mkdir -p "$iconset_dir"
for icon_size in 16 32 128 256 512; do
    sips -z "$icon_size" "$icon_size" "$project_dir/Assets/AppIcon.png" --out "$iconset_dir/icon_${icon_size}x${icon_size}.png" >/dev/null
    retina_size=$((icon_size * 2))
    sips -z "$retina_size" "$retina_size" "$project_dir/Assets/AppIcon.png" --out "$iconset_dir/icon_${icon_size}x${icon_size}@2x.png" >/dev/null
done
python3 "$project_dir/scripts/pack_icon.py" "$iconset_dir" "$app_dir/Contents/Resources/AppIcon.icns"
cp "$binary_dir/SelectionMath" "$app_dir/Contents/MacOS/SelectionMath"
cp -R "$binary_dir/SelectionMath_SelectionMath.bundle" "$app_dir/Contents/Resources/"
cp "$project_dir/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --options runtime --sign - "$app_dir"
codesign --verify --strict "$app_dir"
zip_path="$project_dir/dist/SelectionMath.zip"
/bin/rm -f "$zip_path"
ditto -c -k --keepParent "$app_dir" "$zip_path"
printf '%s\n%s\n' "$app_dir" "$zip_path"
