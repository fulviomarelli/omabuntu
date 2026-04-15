#!/bin/bash
echo "Migrate webapps to Wayland-safe desktop IDs and icon theme cache"

set -e

DESKTOP_DIR="$HOME/.local/share/applications"
SOURCE_ICON_DIR="$HOME/.local/share/applications/icons"
THEME_ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

declare -a webapp_files=()

while IFS= read -r -d '' file; do
  if grep -q '^Exec=.*omakub-launch-webapp.*' "$file"; then
    webapp_files+=("$file")
  fi
done < <(find "$DESKTOP_DIR" -maxdepth 1 -name '*.desktop' -print0 2>/dev/null)

if (( ${#webapp_files[@]} == 0 )); then
  echo "No webapps found to migrate."
  exit 0
fi

for file in "${webapp_files[@]}"; do
  app_name=$(grep -m1 '^Name=' "$file" | cut -d= -f2-)
  exec_line=$(grep -m1 '^Exec=' "$file" || true)
  app_url=$(echo "$exec_line" | sed -n 's/^Exec=.*omakub-launch-webapp[[:space:]]\+"\([^"]*\)".*/\1/p')
  if [[ -z $app_url ]]; then
    app_url=$(echo "$exec_line" | sed -n 's/^Exec=.*omakub-launch-webapp[[:space:]]\+\([^ "][^ ]*\).*/\1/p')
  fi
  icon_ref=$(grep -m1 '^Icon=' "$file" | cut -d= -f2-)

  if [[ -z $app_name || -z $app_url ]]; then
    echo "Skipping webapp migration for $(basename "$file"): missing Name/URL"
    continue
  fi

  if [[ -z $icon_ref ]]; then
    icon_ref="https://www.google.com/s2/favicons?domain=${app_url}&sz=128"
  elif [[ $icon_ref == /* ]]; then
    if [[ ! -f $icon_ref ]]; then
      icon_ref="https://www.google.com/s2/favicons?domain=${app_url}&sz=128"
    fi
  elif [[ -f $SOURCE_ICON_DIR/$icon_ref ]]; then
    icon_ref="$SOURCE_ICON_DIR/$icon_ref"
  elif [[ -f $SOURCE_ICON_DIR/$icon_ref.png ]]; then
    icon_ref="$SOURCE_ICON_DIR/$icon_ref.png"
  elif [[ -f $THEME_ICON_DIR/$icon_ref ]]; then
    icon_ref="$THEME_ICON_DIR/$icon_ref"
  elif [[ -f $THEME_ICON_DIR/$icon_ref.png ]]; then
    icon_ref="$THEME_ICON_DIR/$icon_ref.png"
  else
    icon_ref="https://www.google.com/s2/favicons?domain=${app_url}&sz=128"
  fi

  if ! omakub-webapp-install "$app_name" "$app_url" "$icon_ref"; then
    echo "Skipping failed webapp migration for $app_name"
  fi
done
