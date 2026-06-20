#!/bin/sh
set -eu

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIGURATION="${1:-Release}"
APP_PATH="${PROJECT_DIR}/音转匣.app"
DMG_PATH="${PROJECT_DIR}/音转匣.dmg"
STAGING_DIR="${PROJECT_DIR}/build/dmg"

"${PROJECT_DIR}/build_autoMC.sh" "${CONFIGURATION}"

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
cp -R "${APP_PATH}" "${STAGING_DIR}/音转匣.app"
ln -s /Applications "${STAGING_DIR}/Applications"

rm -f "${DMG_PATH}"
hdiutil create \
  -volname "音转匣" \
  -srcfolder "${STAGING_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

echo "音转匣.dmg 已生成到 ${DMG_PATH}"
