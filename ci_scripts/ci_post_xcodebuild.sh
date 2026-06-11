#!/bin/sh

# Xcode Cloud hook: after an archive action that produced a TestFlight-eligible
# build, attach that build to Fidel's internal TestFlight group so it is visible
# without manual App Store Connect cleanup.
#
# Requires secret environment variables on the Xcode Cloud workflow:
# ASC_KEY_ID, ASC_ISSUER_ID, and one of ASC_PRIVATE_KEY_BASE64 /
# ASC_PRIVATE_KEY / ASC_PRIVATE_KEY_PATH. Intentionally non-fatal: missing
# secrets or App Store Connect lag must not fail an otherwise green build.

set -u

log() {
    printf '%s\n' "[TestFlight group attach] $*"
}

if [ "${FIDEL_TESTFLIGHT_SKIP_ATTACH:-0}" = "1" ]; then
    log "FIDEL_TESTFLIGHT_SKIP_ATTACH=1; skipping."
    exit 0
fi

# The hook fires after every xcodebuild action. Only archive actions upload to
# TestFlight, and only when Xcode Cloud signed the app for App Store distribution.
if [ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]; then
    log "Skipping xcodebuild action '${CI_XCODEBUILD_ACTION:-unknown}'; only archive actions upload to TestFlight."
    exit 0
fi

if [ -z "${CI_APP_STORE_SIGNED_APP_PATH:-}" ]; then
    log "No App Store-signed app produced; this archive does not feed TestFlight."
    exit 0
fi

APP_ID="${FIDEL_ASC_APP_ID:-${ASC_APP_ID:-6758070348}}"
GROUP_ID="${FIDEL_TESTFLIGHT_GROUP_ID:-4695043c-f536-493b-abd4-c4925bda6154}"
GROUP_NAME="${FIDEL_TESTFLIGHT_GROUP_NAME:-Internal Testing}"
PLATFORM="${FIDEL_TESTFLIGHT_PLATFORM:-IOS}"
BUILD_NUMBER="${FIDEL_TESTFLIGHT_BUILD_NUMBER:-${CI_BUILD_NUMBER:-}}"
MAX_ATTEMPTS="${FIDEL_TESTFLIGHT_ATTACH_ATTEMPTS:-30}"
SLEEP_SECONDS="${FIDEL_TESTFLIGHT_ATTACH_SLEEP_SECONDS:-30}"

if [ -z "$BUILD_NUMBER" ]; then
    log "CI_BUILD_NUMBER is unavailable; cannot safely select the current App Store Connect build."
    exit 0
fi

KEY_ID="${ASC_KEY_ID:-}"
ISSUER_ID="${ASC_ISSUER_ID:-}"
PRIVATE_KEY_PATH="${ASC_PRIVATE_KEY_PATH:-}"
TEMP_PRIVATE_KEY=""

cleanup() {
    if [ -n "$TEMP_PRIVATE_KEY" ] && [ -f "$TEMP_PRIVATE_KEY" ]; then
        rm -f "$TEMP_PRIVATE_KEY"
    fi
}
trap cleanup EXIT

if [ -z "$KEY_ID" ] || [ -z "$ISSUER_ID" ]; then
    log "ASC_KEY_ID or ASC_ISSUER_ID is missing; add Xcode Cloud secrets to enable automatic group attach."
    exit 0
fi

if [ -n "$PRIVATE_KEY_PATH" ] && [ -r "$PRIVATE_KEY_PATH" ]; then
    :
elif [ -n "${ASC_PRIVATE_KEY_BASE64:-}" ]; then
    TEMP_PRIVATE_KEY="$(mktemp "${TMPDIR:-/tmp}/fidel-asc-key.XXXXXX")"
    printf '%s' "$ASC_PRIVATE_KEY_BASE64" | base64 --decode > "$TEMP_PRIVATE_KEY"
    PRIVATE_KEY_PATH="$TEMP_PRIVATE_KEY"
elif [ -n "${ASC_PRIVATE_KEY:-}" ]; then
    TEMP_PRIVATE_KEY="$(mktemp "${TMPDIR:-/tmp}/fidel-asc-key.XXXXXX")"
    printf '%s\n' "$ASC_PRIVATE_KEY" > "$TEMP_PRIVATE_KEY"
    PRIVATE_KEY_PATH="$TEMP_PRIVATE_KEY"
else
    log "ASC_PRIVATE_KEY_PATH, ASC_PRIVATE_KEY_BASE64, or ASC_PRIVATE_KEY is missing; cannot call App Store Connect."
    exit 0
fi

make_jwt() {
    ASC_KEY_ID="$KEY_ID" \
    ASC_ISSUER_ID="$ISSUER_ID" \
    ASC_PRIVATE_KEY_PATH="$PRIVATE_KEY_PATH" \
    ruby -ropenssl -rjson -rbase64 -e '
def b64url(value)
  Base64.urlsafe_encode64(value).delete("=")
end

header = {
  alg: "ES256",
  kid: ENV.fetch("ASC_KEY_ID"),
  typ: "JWT"
}
now = Time.now.to_i
payload = {
  iss: ENV.fetch("ASC_ISSUER_ID"),
  iat: now - 60,
  exp: now + 20 * 60,
  aud: "appstoreconnect-v1"
}

unsigned = [b64url(JSON.generate(header)), b64url(JSON.generate(payload))].join(".")
key = OpenSSL::PKey.read(File.read(ENV.fetch("ASC_PRIVATE_KEY_PATH")))
der = key.sign(OpenSSL::Digest::SHA256.new, unsigned)
sequence = OpenSSL::ASN1.decode(der)
raw_signature = sequence.value.map { |integer| integer.value.to_s(2).rjust(32, "\0") }.join
puts [unsigned, b64url(raw_signature)].join(".")
'
}

# Builds appear in the API while still PROCESSING, but App Store Connect
# rejects group attachment until processingState is VALID, so filter on it and
# let the retry loop cover both upload lag and processing time.
fetch_build_id() {
    token="$1"
    response="$(curl -sS --get \
        "https://api.appstoreconnect.apple.com/v1/builds" \
        --header "Authorization: Bearer $token" \
        --data-urlencode "filter[app]=$APP_ID" \
        --data-urlencode "filter[version]=$BUILD_NUMBER" \
        --data-urlencode "filter[processingState]=VALID" \
        --data-urlencode "filter[preReleaseVersion.platform]=$PLATFORM" \
        --data-urlencode "sort=-uploadedDate" \
        --data-urlencode "limit=1")" || return 1

    printf '%s' "$response" | ruby -rjson -e '
json = JSON.parse(STDIN.read)
build = Array(json["data"]).first
exit 1 unless build
puts build.fetch("id")
'
}

attach_group() {
    token="$1"
    build_id="$2"
    body_file="$(mktemp "${TMPDIR:-/tmp}/fidel-attach-body.XXXXXX")"
    response_file="$(mktemp "${TMPDIR:-/tmp}/fidel-attach-response.XXXXXX")"

    printf '{"data":[{"type":"builds","id":"%s"}]}' "$build_id" > "$body_file"
    status_code="$(curl -sS -o "$response_file" -w "%{http_code}" \
        --request POST \
        "https://api.appstoreconnect.apple.com/v1/betaGroups/$GROUP_ID/relationships/builds" \
        --header "Authorization: Bearer $token" \
        --header "Content-Type: application/json" \
        --data-binary "@$body_file")"

    rm -f "$body_file"

    case "$status_code" in
        200|201|204)
            rm -f "$response_file"
            return 0
            ;;
        409)
            log "ASC returned 409 while attaching build $build_id; treating as already attached/non-fatal."
            cat "$response_file"
            rm -f "$response_file"
            return 0
            ;;
        *)
            log "ASC returned HTTP $status_code while attaching build $build_id to group '$GROUP_NAME'."
            cat "$response_file"
            rm -f "$response_file"
            return 1
            ;;
    esac
}

BUILD_ID=""
attempt=1

while [ "$attempt" -le "$MAX_ATTEMPTS" ]; do
    # Mint a fresh short-lived token each attempt so long processing waits
    # never outlive the JWT.
    TOKEN="$(make_jwt)"
    if BUILD_ID="$(fetch_build_id "$TOKEN" 2>/dev/null)"; then
        break
    fi

    log "Build $BUILD_NUMBER is not VALID in App Store Connect yet (attempt $attempt/$MAX_ATTEMPTS)."
    attempt=$((attempt + 1))
    sleep "$SLEEP_SECONDS"
done

if [ -z "$BUILD_ID" ]; then
    log "Build $BUILD_NUMBER did not finish processing during this hook; leaving workflow green."
    exit 0
fi

if attach_group "$TOKEN" "$BUILD_ID"; then
    log "Attached build $BUILD_NUMBER ($BUILD_ID) to TestFlight group '$GROUP_NAME'."
else
    log "Could not attach build $BUILD_NUMBER to TestFlight group '$GROUP_NAME'; leaving workflow green."
fi

exit 0
