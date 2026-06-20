#!/bin/sh
set -eu

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIGURATION="${1:-Release}"
DERIVED_DATA_PATH="${PROJECT_DIR}/build/DerivedData"

xcodebuild \
  -project "${PROJECT_DIR}/autoMC.xcodeproj" \
  -scheme autoMC \
  -configuration "${CONFIGURATION}" \
  -derivedDataPath "${DERIVED_DATA_PATH}" \
  build

APP_SOURCE="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/音转匣.app"
APP_DESTINATION="${PROJECT_DIR}/音转匣.app"
VENDOR_FFMPEG="${PROJECT_DIR}/Vendor/ffmpeg/ffmpeg"
VENDOR_FFMPEG_LICENSE="${PROJECT_DIR}/Vendor/ffmpeg/LICENSE"
VENDOR_FFMPEG_README="${PROJECT_DIR}/Vendor/ffmpeg/README"
ENTITLEMENTS="${PROJECT_DIR}/autoMC/autoMC.entitlements"

rm -rf "${APP_DESTINATION}"
cp -R "${APP_SOURCE}" "${APP_DESTINATION}"

if [ -x "${VENDOR_FFMPEG}" ]; then
  mkdir -p "${APP_DESTINATION}/Contents/Resources/bin"
  cp "${VENDOR_FFMPEG}" "${APP_DESTINATION}/Contents/Resources/bin/ffmpeg"
  chmod 755 "${APP_DESTINATION}/Contents/Resources/bin/ffmpeg"

  mkdir -p "${APP_DESTINATION}/Contents/Resources/licenses/ffmpeg"
  cp "${VENDOR_FFMPEG_LICENSE}" "${APP_DESTINATION}/Contents/Resources/licenses/ffmpeg/LICENSE"
  cp "${VENDOR_FFMPEG_README}" "${APP_DESTINATION}/Contents/Resources/licenses/ffmpeg/README"
fi

codesign --force --deep --sign - --entitlements "${ENTITLEMENTS}" "${APP_DESTINATION}"

echo "音转匣.app 已复制到 ${APP_DESTINATION}"
