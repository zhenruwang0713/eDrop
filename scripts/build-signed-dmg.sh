#!/usr/bin/env bash
# Build, Developer ID-sign, notarize, staple, and pack 点译 · eDrop into a .dmg.
#
# Packaging only. This script does not change translation, selection, overlay,
# or menu-bar behavior. The Xcode project keeps ad-hoc signing
# (CODE_SIGN_IDENTITY="-", empty DEVELOPMENT_TEAM) for local runs. Developer ID
# settings below are passed on the xcodebuild / codesign command line.
#
# Run on macOS with Xcode (xcodebuild, codesign, notarytool, stapler, hdiutil).
# Output is written under dist/ (gitignored). This script does not upload
# GitHub Releases.
#
# Required environment variables or flags
# ---------------------------------------
# TEAM_ID
#     10-character Apple Developer Team ID. Flag: --team-id TEAM_ID
#
# Signing identity — one of:
#   CODESIGN_IDENTITY
#       Full certificate name, for example:
#       Developer ID Application: Zhenru Wang (TEAMID)
#       Flag: --identity "Developer ID Application: ..."
#   If CODESIGN_IDENTITY is unset, the script selects the single
#   "Developer ID Application" identity in the login keychain whose name
#   contains (TEAM_ID). Zero or several matches is an error.
#
# Notarization — one of:
#   NOTARY_PROFILE
#       Keychain profile from `xcrun notarytool store-credentials`.
#   OR all of:
#       APPLE_ID
#       APPLE_APP_SPECIFIC_PASSWORD
#           App-specific password from appleid.apple.com, not the Apple ID password.
#       TEAM_ID
#
# Optional flags
#   --scheme NAME            default: eDrop
#   --configuration NAME     default: Release
#   -h, --help
#
# The disk image name follows MARKETING_VERSION in eDrop.xcodeproj
# (0.3.18 → dist/点译-eDrop-0.3.18.dmg).
#
# Notarization is submitted twice: once for the .app (so a copy in
# /Applications keeps a stapled ticket) and once for the .dmg the user downloads.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${ROOT}/eDrop.xcodeproj"
PBXPROJ="${PROJECT}/project.pbxproj"
ENTITLEMENTS="${ROOT}/Resources/EyedropTranslate.entitlements"
SCHEME="eDrop"
CONFIGURATION="Release"
DIST="${ROOT}/dist"
BUNDLE_ID="app.eyedrop.translate"

TEAM_ID="${TEAM_ID:-}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

die() {
  printf 'error: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: scripts/build-signed-dmg.sh [--team-id TEAM_ID] [--identity CERT] [--scheme NAME] [--configuration NAME]

Build Release eDrop.app, sign with Developer ID Application, notarize, staple,
and write dist/点译-eDrop-<marketing-version>.dmg.

Required:
  TEAM_ID                 Apple Developer Team ID (10 letters or digits)
  Signing identity        CODESIGN_IDENTITY or the unique Developer ID
                          Application certificate for TEAM_ID in the keychain
  Notarization            NOTARY_PROFILE
                          or APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD + TEAM_ID

APPLE_APP_SPECIFIC_PASSWORD is an app-specific password from appleid.apple.com,
not your Apple ID password.

The script exits before building when the Developer ID identity or notarization
credentials are missing. Run --help to print this text. See
scripts/README-RELEASE.md.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --team-id)
      [[ $# -ge 2 ]] || die "--team-id requires a value (10-character Apple Team ID)."
      TEAM_ID="$2"
      shift 2
      ;;
    --identity)
      [[ $# -ge 2 ]] || die "--identity requires the full certificate name, for example: Developer ID Application: Name (TEAMID)"
      CODESIGN_IDENTITY="$2"
      shift 2
      ;;
    --scheme)
      [[ $# -ge 2 ]] || die "--scheme requires a value."
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      [[ $# -ge 2 ]] || die "--configuration requires a value (Release)."
      CONFIGURATION="$2"
      shift 2
      ;;
    *)
      die "unknown argument: $1. Run scripts/build-signed-dmg.sh --help."
      ;;
  esac
done

require_macos() {
  local os
  os="$(uname -s)"
  if [[ "${os}" != "Darwin" ]]; then
    die "this script must be run on macOS with Xcode. Current system is ${os}. Install Xcode on a Mac, install the Developer ID Application certificate, then run scripts/build-signed-dmg.sh. See scripts/README-RELEASE.md."
  fi
}

require_tools() {
  local missing
  missing=""
  for tool in xcodebuild codesign security hdiutil ditto plutil spctl; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      missing="${missing} ${tool}"
    fi
  done
  if [[ -n "${missing}" ]]; then
    die "missing macOS tools:${missing}. Install Xcode and point xcode-select at it: sudo xcode-select -s /Applications/Xcode.app"
  fi
  if ! xcrun --find notarytool >/dev/null 2>&1; then
    die "notarytool was not found. Install Xcode 13 or newer and run: sudo xcode-select -s /Applications/Xcode.app"
  fi
  if ! xcrun --find stapler >/dev/null 2>&1; then
    die "stapler was not found. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app"
  fi
}

read_setting() {
  local key="$1"
  local found
  found="$(awk -v key="${key}" '
    $1 == key && $2 == "=" {
      val = $3
      sub(/;$/, "", val)
      print val
    }
  ' "${PBXPROJ}" | sort -u)"
  if [[ -z "${found}" ]]; then
    die "could not read ${key} from ${PBXPROJ}."
  fi
  case "${found}" in
    *$'\n'*)
      die "${key} has more than one value in ${PBXPROJ}: ${found}"
      ;;
  esac
  printf '%s\n' "${found}"
}

load_version() {
  [[ -f "${PBXPROJ}" ]] || die "Xcode project not found at ${PROJECT}."
  [[ -f "${PROJECT}/xcshareddata/xcschemes/${SCHEME}.xcscheme" ]] || die "shared scheme not found: ${SCHEME}. Pass --scheme with a scheme under eDrop.xcodeproj/xcshareddata/xcschemes/."
  [[ -f "${ENTITLEMENTS}" ]] || die "entitlements file not found: ${ENTITLEMENTS}."
  MARKETING_VERSION="$(read_setting MARKETING_VERSION)"
  BUILD_VERSION="$(read_setting CURRENT_PROJECT_VERSION)"
  if [[ ! "${MARKETING_VERSION}" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
    die "MARKETING_VERSION in the Xcode project is not a dotted numeric version: ${MARKETING_VERSION}"
  fi
  if [[ ! "${BUILD_VERSION}" =~ ^[0-9]+$ ]]; then
    die "CURRENT_PROJECT_VERSION in the Xcode project is not an integer: ${BUILD_VERSION}"
  fi
}

list_identities() {
  local output status
  set +e
  output="$(security find-identity -v -p codesigning 2>&1)"
  status=$?
  set -e
  if [[ "${status}" -ne 0 ]]; then
    die "could not list code signing identities (security find-identity exited ${status}).

${output}

Unlock the login keychain, install the Developer ID Application certificate and its private key, then run:

  security unlock-keychain \"\$HOME/Library/Keychains/login.keychain-db\"
  security find-identity -v -p codesigning"
  fi
  printf '%s\n' "${output}"
}

resolve_identity() {
  local id_list matches count line parsed team_tag
  if [[ -z "${TEAM_ID}" ]]; then
    die "TEAM_ID is required.

Export the 10-character Apple Developer Team ID, or pass --team-id:

  export TEAM_ID=XXXXXXXXXX
  scripts/build-signed-dmg.sh

The Team ID is the value in parentheses on the certificate:
  Developer ID Application: Your Name (TEAMID)

Find it under Apple Developer → Membership, or in Xcode → Settings → Accounts."
  fi
  if [[ ! "${TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
    die "TEAM_ID must be exactly 10 letters or digits. Got: ${TEAM_ID}"
  fi

  id_list="$(list_identities)"

  if [[ -n "${CODESIGN_IDENTITY}" ]]; then
    case "${CODESIGN_IDENTITY}" in
      "Developer ID Application:"*)
        ;;
      *)
        die "CODESIGN_IDENTITY must be a Developer ID Application certificate. Apple Development, Mac Developer, and ad-hoc \"-\" cannot be notarized.

Got: ${CODESIGN_IDENTITY}

Example:
  export CODESIGN_IDENTITY=\"Developer ID Application: Your Name (${TEAM_ID})\""
        ;;
    esac
    team_tag="(${TEAM_ID})"
    case "${CODESIGN_IDENTITY}" in
      *"${team_tag}"*)
        ;;
      *)
        die "CODESIGN_IDENTITY does not contain team ${team_tag}.

Got: ${CODESIGN_IDENTITY}

Use the certificate that ends with (${TEAM_ID}), or set TEAM_ID to the team inside that certificate name."
        ;;
    esac
    if ! printf '%s\n' "${id_list}" | grep -F "${CODESIGN_IDENTITY}" >/dev/null; then
      die "CODESIGN_IDENTITY is not in the keychain (security find-identity only lists certificates that have a private key).

Missing: ${CODESIGN_IDENTITY}

Install the Developer ID Application certificate and its private key in the login keychain. Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application.

Identities currently visible:
${id_list}"
    fi
    IDENTITY="${CODESIGN_IDENTITY}"
    return 0
  fi

  matches="$(printf '%s\n' "${id_list}" | grep "Developer ID Application:" | grep -F "(${TEAM_ID})" || true)"
  count=0
  parsed=""
  if [[ -n "${matches}" ]]; then
    while IFS= read -r line; do
      [[ -z "${line}" ]] && continue
      count=$((count + 1))
      parsed="$(printf '%s\n' "${line}" | sed -n 's/.*"\(Developer ID Application:[^"]*\)".*/\1/p')"
    done < <(printf '%s\n' "${matches}")
  fi

  if [[ "${count}" -eq 0 ]]; then
    die "no Developer ID Application identity for team ${TEAM_ID} was found in the keychain.

Install that certificate and its private key (Xcode → Settings → Accounts → Manage Certificates → Developer ID Application, or the Apple Developer portal). Then re-run, or set the full name:

  export TEAM_ID=${TEAM_ID}
  export CODESIGN_IDENTITY=\"Developer ID Application: Your Name (${TEAM_ID})\"

Identities currently visible:
${id_list}"
  fi
  if [[ "${count}" -gt 1 ]]; then
    die "multiple Developer ID Application identities match team ${TEAM_ID}. Set CODESIGN_IDENTITY to the exact certificate name:

${matches}"
  fi
  if [[ -z "${parsed}" ]]; then
    die "found a Developer ID Application identity for team ${TEAM_ID} but could not parse the certificate name. Set CODESIGN_IDENTITY explicitly.

Line:
${matches}"
  fi
  IDENTITY="${parsed}"
}

resolve_notary() {
  local missing
  if [[ -n "${NOTARY_PROFILE}" ]]; then
    NOTARY_MODE="profile"
    return 0
  fi
  missing=""
  [[ -z "${APPLE_ID}" ]] && missing="${missing} APPLE_ID"
  [[ -z "${APPLE_APP_SPECIFIC_PASSWORD}" ]] && missing="${missing} APPLE_APP_SPECIFIC_PASSWORD"
  [[ -z "${TEAM_ID}" ]] && missing="${missing} TEAM_ID"
  if [[ -n "${missing}" ]]; then
    die "notarization credentials are missing:${missing}.

Provide a notarytool keychain profile:

  export NOTARY_PROFILE=\"edrop-notary\"
  xcrun notarytool store-credentials \"\${NOTARY_PROFILE}\" --apple-id \"you@example.com\" --team-id \"\${TEAM_ID}\"

or set all of these:

  export APPLE_ID=\"you@example.com\"
  export APPLE_APP_SPECIFIC_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\"
  export TEAM_ID=\"${TEAM_ID:-XXXXXXXXXX}\"

APPLE_APP_SPECIFIC_PASSWORD is an app-specific password from https://appleid.apple.com (Sign-In and Security → App-Specific Passwords), not your Apple ID password."
  fi
  NOTARY_MODE="apple-id"
}

archive_app() {
  local log
  log="${DIST}/xcodebuild-archive.log"
  echo "Archiving ${SCHEME} (${CONFIGURATION}) with Developer ID..."
  if ! xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -configuration "${CONFIGURATION}" \
    -destination "generic/platform=macOS" \
    -archivePath "${DIST}/eDrop.xcarchive" \
    archive \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    CODE_SIGN_STYLE=Manual \
    "CODE_SIGN_IDENTITY=${IDENTITY}" \
    ENABLE_HARDENED_RUNTIME=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    ONLY_ACTIVE_ARCH=NO \
    "PRODUCT_BUNDLE_IDENTIFIER=${BUNDLE_ID}" \
    "OTHER_CODE_SIGN_FLAGS=--timestamp --options=runtime" \
    2>&1 | tee "${log}"; then
    die "xcodebuild archive failed. The log is ${log}.

Common causes: Xcode is not selected (sudo xcode-select -s /Applications/Xcode.app), the login keychain is locked, or the Developer ID private key does not match ${IDENTITY}."
  fi
  [[ -d "${DIST}/eDrop.xcarchive" ]] || die "xcodebuild archive did not create ${DIST}/eDrop.xcarchive. See ${log}."
}

copy_archived_app() {
  local products candidate
  products="${DIST}/eDrop.xcarchive/Products"
  [[ -d "${products}" ]] || die "archive has no Products directory at ${products}."
  ARCHIVE_APP=""
  while IFS= read -r -d '' candidate; do
    if [[ -z "${ARCHIVE_APP}" ]]; then
      ARCHIVE_APP="${candidate}"
    fi
  done < <(find "${products}" -name 'eDrop.app' -type d -print0)
  [[ -n "${ARCHIVE_APP}" ]] || die "archive did not contain eDrop.app under ${products}."
}

try_export_archive() {
  local plist exported candidate log
  plist="${DIST}/ExportOptions.plist"
  log="${DIST}/xcodebuild-export.log"
  cat >"${plist}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>method</key>
	<string>developer-id</string>
	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>${IDENTITY}</string>
	<key>teamID</key>
	<string>${TEAM_ID}</string>
</dict>
</plist>
EOF
  rm -rf "${DIST}/export"
  echo "Exporting archive with method developer-id..."
  if xcodebuild -exportArchive \
    -archivePath "${DIST}/eDrop.xcarchive" \
    -exportPath "${DIST}/export" \
    -exportOptionsPlist "${plist}" \
    2>&1 | tee "${log}"; then
    exported=""
    if [[ -d "${DIST}/export" ]]; then
      while IFS= read -r -d '' candidate; do
        if [[ -z "${exported}" ]]; then
          exported="${candidate}"
        fi
      done < <(find "${DIST}/export" -name 'eDrop.app' -type d -print0)
    fi
    if [[ -n "${exported}" ]]; then
      rm -rf "${DIST}/eDrop.app"
      ditto "${exported}" "${DIST}/eDrop.app"
      return 0
    fi
  fi
  echo "exportArchive did not produce eDrop.app. A Developer ID provisioning profile is often absent for this non-sandboxed app. The archived app will be signed directly with Developer ID Application."
  rm -rf "${DIST}/eDrop.app"
  ditto "${ARCHIVE_APP}" "${DIST}/eDrop.app"
}

sign_app() {
  local item
  local app="${DIST}/eDrop.app"
  [[ -d "${app}" ]] || die "expected app at ${app} before codesign."
  if [[ -d "${app}/Contents" ]]; then
    while IFS= read -r -d '' item; do
      echo "Signing nested code: ${item}"
      if ! codesign --force --sign "${IDENTITY}" --timestamp --options runtime "${item}"; then
        die "codesign failed for nested code ${item}. Unlock the login keychain and confirm ${IDENTITY} has a private key."
      fi
    done < <(find "${app}/Contents" -depth \( -name '*.dylib' -o -name '*.framework' -o -name '*.xpc' -o -name '*.appex' \) -print0)
  fi
  echo "Signing ${app} with ${IDENTITY}"
  if ! codesign --force --sign "${IDENTITY}" \
    --entitlements "${ENTITLEMENTS}" \
    --timestamp \
    --options runtime \
    --generate-entitlement-der \
    "${app}"; then
    die "codesign failed for ${app}. Confirm \"${IDENTITY}\" is a Developer ID Application certificate with a private key, and that the login keychain is unlocked."
  fi
}

require_developer_id_signature() {
  local target="$1"
  local expect_runtime="$2"
  local sig ents
  sig="$(codesign -dv --verbose=4 "${target}" 2>&1 || true)"
  printf '%s\n' "${sig}"
  if ! printf '%s\n' "${sig}" | grep -q "Authority=Developer ID Application:"; then
    die "signature of ${target} is not Developer ID Application. Install the Developer ID certificate and re-run. codesign output is above."
  fi
  if ! printf '%s\n' "${sig}" | grep -q "Authority=Developer ID Certification Authority"; then
    die "signature of ${target} is missing the Developer ID Certification Authority chain. The certificate is not a Developer ID Application certificate."
  fi
  if ! printf '%s\n' "${sig}" | grep -q "TeamIdentifier=${TEAM_ID}"; then
    die "signature team of ${target} does not match TEAM_ID ${TEAM_ID}."
  fi
  if ! printf '%s\n' "${sig}" | grep -q "Timestamp="; then
    die "signature of ${target} has no secure timestamp. Notarization rejects untimestamped Developer ID signatures. codesign must reach Apple's timestamp server."
  fi
  if printf '%s\n' "${sig}" | grep -q "Timestamp=none"; then
    die "signature of ${target} has Timestamp=none. Check the network path to Apple's timestamp server and sign again."
  fi
  if [[ "${expect_runtime}" == "yes" ]]; then
    if ! printf '%s\n' "${sig}" | grep -q "flags=.*runtime"; then
      die "hardened runtime is missing on ${target}. Notarization requires it. The script passes ENABLE_HARDENED_RUNTIME=YES and codesign --options runtime."
    fi
    ents="$(codesign -d --entitlements :- "${target}" 2>/dev/null || true)"
    if printf '%s\n' "${ents}" | grep -q "get-task-allow"; then
      die "signature of ${target} contains get-task-allow. Notarization rejects that debug entitlement. The distribution build sets CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO."
    fi
  fi
  if ! codesign --verify --strict --verbose=2 "${target}"; then
    die "codesign --verify --strict failed for ${target}."
  fi
}

require_bundle_identity() {
  local app plist bid version build
  app="${DIST}/eDrop.app"
  plist="${app}/Contents/Info.plist"
  [[ -f "${plist}" ]] || die "built app is missing ${plist}."
  bid="$(plutil -extract CFBundleIdentifier raw -o - "${plist}")"
  version="$(plutil -extract CFBundleShortVersionString raw -o - "${plist}")"
  build="$(plutil -extract CFBundleVersion raw -o - "${plist}")"
  if [[ "${bid}" != "${BUNDLE_ID}" ]]; then
    die "built bundle id is ${bid}. Expected ${BUNDLE_ID}."
  fi
  if [[ "${version}" != "${MARKETING_VERSION}" ]]; then
    die "built CFBundleShortVersionString is ${version}. Expected MARKETING_VERSION ${MARKETING_VERSION} from the Xcode project."
  fi
  if [[ "${build}" != "${BUILD_VERSION}" ]]; then
    die "built CFBundleVersion is ${build}. Expected CURRENT_PROJECT_VERSION ${BUILD_VERSION} from the Xcode project."
  fi
  echo "Bundle ${bid} version ${version} (${build})"
}

notary_submit() {
  local artifact="$1"
  local log="$2"
  local status
  echo "Submitting ${artifact} to Apple notarytool..."
  set +e
  if [[ "${NOTARY_MODE}" == "profile" ]]; then
    echo "Notarization credentials: keychain profile ${NOTARY_PROFILE}"
    xcrun notarytool submit "${artifact}" \
      --keychain-profile "${NOTARY_PROFILE}" \
      --wait \
      --timeout 30m \
      --output-format json \
      >"${log}" 2>&1
    status=$?
  else
    echo "Notarization credentials: Apple ID ${APPLE_ID}, team ${TEAM_ID}"
    xcrun notarytool submit "${artifact}" \
      --apple-id "${APPLE_ID}" \
      --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
      --team-id "${TEAM_ID}" \
      --wait \
      --timeout 30m \
      --output-format json \
      >"${log}" 2>&1
    status=$?
  fi
  set -e
  cat "${log}"
  if [[ "${status}" -ne 0 ]]; then
    die "notarization failed for ${artifact} (notarytool exit ${status}). See ${log}. Fetch Apple's log with the submission id: xcrun notarytool log <id> $(notary_auth_hint)"
  fi
  if ! grep -q '"status"[[:space:]]*:[[:space:]]*"Accepted"' "${log}"; then
    die "notarization of ${artifact} did not report status Accepted. See ${log}."
  fi
}

notary_auth_hint() {
  if [[ "${NOTARY_MODE}" == "profile" ]]; then
    printf '%s\n' "--keychain-profile \"${NOTARY_PROFILE}\""
  else
    printf '%s\n' "--apple-id \"${APPLE_ID}\" --team-id \"${TEAM_ID}\""
  fi
}

submission_id_from() {
  local log="$1"
  awk -F'"' '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == "id") {
          print $(i + 2)
          exit
        }
      }
    }
  ' "${log}"
}

staple_target() {
  local target="$1"
  echo "Stapling notarization ticket to ${target}"
  if ! xcrun stapler staple "${target}"; then
    die "stapler could not attach the notarization ticket to ${target}. The upload may have been accepted under a different code hash. See the notary log in ${DIST}."
  fi
  if ! xcrun stapler validate "${target}"; then
    die "stapler validate failed for ${target}."
  fi
}

make_dmg() {
  local stage volname
  volname="点译-eDrop-${MARKETING_VERSION}"
  stage="${DIST}/dmg-root"
  DMG="${DIST}/${volname}.dmg"
  rm -rf "${stage}"
  mkdir -p "${stage}"
  ditto "${DIST}/eDrop.app" "${stage}/eDrop.app"
  ln -s /Applications "${stage}/Applications"
  rm -f "${DMG}"
  echo "Creating ${DMG}"
  if ! hdiutil create \
    -volname "${volname}" \
    -srcfolder "${stage}" \
    -ov \
    -format UDZO \
    "${DMG}"; then
    die "hdiutil could not create ${DMG}."
  fi
  echo "Signing disk image with ${IDENTITY}"
  if ! codesign --force --sign "${IDENTITY}" --timestamp "${DMG}"; then
    die "codesign failed for ${DMG}. Disk images are signed with the same Developer ID Application identity as the app, without the hardened-runtime flag."
  fi
}

print_outputs() {
  local app_id dmg_id
  app_id="$(submission_id_from "${DIST}/notary-app.log" || true)"
  dmg_id="$(submission_id_from "${DIST}/notary-dmg.log" || true)"
  echo ""
  echo "Signed and notarized artifacts:"
  echo "  App: ${DIST}/eDrop.app"
  echo "  DMG: ${DMG}"
  echo "  Archive log: ${DIST}/xcodebuild-archive.log"
  echo "  App notarization log: ${DIST}/notary-app.log"
  echo "  DMG notarization log: ${DIST}/notary-dmg.log"
  if [[ -n "${app_id}" ]]; then
    echo "  App notarization id: ${app_id}"
  fi
  if [[ -n "${dmg_id}" ]]; then
    echo "  DMG notarization id: ${dmg_id}"
  fi
  if command -v shasum >/dev/null 2>&1; then
    echo "  SHA-256:"
    shasum -a 256 "${DMG}"
  elif command -v sha256sum >/dev/null 2>&1; then
    echo "  SHA-256:"
    sha256sum "${DMG}"
  fi
  echo ""
  echo "Upload is a separate step. This script does not publish GitHub Releases."
}

main() {
  local zip
  require_macos
  require_tools
  load_version
  resolve_identity
  resolve_notary

  echo "点译 · eDrop ${MARKETING_VERSION} (${BUILD_VERSION})"
  echo "Bundle id: ${BUNDLE_ID}"
  echo "Signing identity: ${IDENTITY}"
  if [[ "${NOTARY_MODE}" == "profile" ]]; then
    echo "Notarization: keychain profile ${NOTARY_PROFILE}"
    if [[ -n "${APPLE_ID}" ]]; then
      echo "APPLE_ID is set and ignored because NOTARY_PROFILE is set."
    fi
  else
    echo "Notarization: Apple ID ${APPLE_ID}, team ${TEAM_ID}"
  fi
  echo "Output directory: ${DIST}"

  mkdir -p "${DIST}"
  rm -rf "${DIST}/eDrop.xcarchive" "${DIST}/export" "${DIST}/eDrop.app" "${DIST}/dmg-root"
  archive_app
  copy_archived_app
  try_export_archive
  sign_app
  require_developer_id_signature "${DIST}/eDrop.app" yes
  require_bundle_identity

  zip="${DIST}/eDrop-${MARKETING_VERSION}.zip"
  rm -f "${zip}"
  ditto -c -k --keepParent "${DIST}/eDrop.app" "${zip}"
  notary_submit "${zip}" "${DIST}/notary-app.log"
  staple_target "${DIST}/eDrop.app"
  if ! spctl --assess --type execute --verbose=4 "${DIST}/eDrop.app"; then
    die "Gatekeeper rejected ${DIST}/eDrop.app after stapling. See the assessment above."
  fi

  make_dmg
  require_developer_id_signature "${DMG}" no
  notary_submit "${DMG}" "${DIST}/notary-dmg.log"
  staple_target "${DMG}"
  if ! spctl --assess --type open --verbose=4 "${DMG}"; then
    die "Gatekeeper rejected ${DMG} after stapling. See the assessment above."
  fi

  print_outputs
}

main "$@"
