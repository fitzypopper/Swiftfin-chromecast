#!/usr/bin/env bash
# Preflight check for the Swiftfin-chromecast iOS build (Google Cast support fork).
# Catches deterministic build failures locally, before burning a ~12 min CI run.
#
# Checks:
#   1. project.pbxproj sanity:
#        - every PBXFileReference path resolves under the repo root
#        - every PBXFileSystemSynchronizedRootGroup directory exists
#        - no duplicate referenced paths, no source-root pre-prefixed paths
#   2. iOS Info.plist is valid XML with the expected keys + ATS config.
#   3. GoogleCast.xcframework integrity (both slices + static binaries) and
#      ChromeCastFramework.json present.
#   4. All expected Chromecast source files exist in the synced groups.
#   5. Cast files are #if canImport(GoogleCast) guarded (Shared/ is also in the
#      tvOS target, so an unguarded file breaks tvOS).
#   6. VideoPlayerType / player switches / app init wiring for the .cast case.
#   7. Bundle ID override for the iOS target is still the fork's identifier.
#   8. Known Swift compile pitfalls in the Cast code (renamed colors, removed
#      APIs, force-unwraps).
#
# NOTE: Swiftfin uses Xcode 16 PBXFileSystemSynchronizedRootGroup for its
# source folders, so new files are auto-included in the target — no pbxproj
# edits needed. That also means a deleted file vanishes silently; this script
# pins the files that must exist.
#
# Usage: ./preflight.sh   (exit 0 = OK, non-zero = problems found)

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"

PBX="$ROOT/Swiftfin.xcodeproj/project.pbxproj"
PLIST="$ROOT/Swiftfin/Resources/Info.plist"
XCFW="$ROOT/Frameworks/GoogleCast.xcframework"
CAST_JSON="$ROOT/ChromeCastFramework.json"
IOS_BUNDLE_ID="org.fitzypopper.swiftfin-chromecast"

# Files that must exist. The first four live under Shared/Services or
# Shared/Components; the rest are expected to contain .cast wiring.
CAST_SOURCES=(
    "Shared/Services/Chromecast/CastPlayerManager.swift"
    "Shared/Services/Chromecast/CastSessionManager.swift"
    "Shared/Services/Chromecast/JellyfinCastReceiverID.swift"
    "Shared/Components/CastButton.swift"
    "Shared/Components/CastDevicePicker.swift"
    "Shared/Objects/MediaPlayerManager/MediaPlayerProxy/MediaPlayerProxy+Cast.swift"
    "Shared/Objects/VideoPlayerType/VideoPlayerType+Cast.swift"
)

errors=0
warn=0

say_err() { echo "  [FAIL] $*"; errors=$((errors + 1)); }
say_warn() { echo "  [WARN] $*"; warn=$((warn + 1)); }

echo "== Swiftfin-chromecast preflight =="

# --- 1. project.pbxproj ---
if [ ! -f "$PBX" ]; then
    say_err "missing $PBX"
else
    echo "-- Checking PBXFileReference paths --"
    while IFS= read -r line; do
        path=$(printf '%s' "$line" | sed -n 's/.*[ ;]path = \("[^"]*"\|[^;]*\);.*/\1/p' | tr -d '"')
        tree=$(printf '%s' "$line" | sed -n 's/.*sourceTree = \([^;]*\);.*/\1/p')
        [ -z "$path" ] && continue

        case "$tree" in
            SOURCE_ROOT|"<group>")
                resolved="$ROOT/$path"
                ;;
            BUILT_PRODUCTS_DIR|SDKROOT)
                continue
                ;;
            *)
                continue
                ;;
        esac

        if [ ! -e "$resolved" ]; then
            say_err "unresolved path ($tree): $path  ->  $resolved"
        fi
    done < <(grep -E 'isa = PBXFileReference;' "$PBX")

    echo "-- Checking synchronized root group dirs --"
    while IFS= read -r line; do
        path=$(printf '%s' "$line" | sed -n 's/.*path = \("[^"]*"\|[^;]*\);.*/\1/p' | tr -d '"')
        [ -z "$path" ] && continue
        if [ ! -d "$ROOT/$path" ]; then
            say_err "synchronized group dir missing: $ROOT/$path"
        fi
    done < <(grep -E 'isa = PBXFileSystemSynchronizedRootGroup;' "$PBX")

    # Guard against source-root pre-prefixed paths (duplicate-nesting bug).
    if grep -qE 'path = (Swiftfin|Shared|Swiftfin tvOS|XcodeConfig|SwiftfinTests)/' "$PBX"; then
        say_err "path pre-prefixed with a synchronized group dir: Swiftfin/Shared/etc. found"
    fi

    # Duplicate file reference paths (same path, different IDs).
    echo "-- Checking for duplicate file references --"
    duplicate_paths=$(
        grep -E 'isa = PBXFileReference;' "$PBX" |
        sed -n 's/.*path = "\([^"]*\)".*/\1/p' |
        sort | uniq -d
    )
    if [ -n "$duplicate_paths" ]; then
        echo "$duplicate_paths" | while IFS= read -r p; do
            say_err "duplicate file reference path: $p"
        done
    fi
fi

# --- 2. Info.plist ---
echo "-- Checking Info.plist --"
if [ ! -f "$PLIST" ]; then
    say_err "missing $PLIST"
else
    if ! plutil -lint "$PLIST" >/dev/null 2>&1; then
        if ! python3 -c "import xml.dom.minidom,sys; xml.dom.minidom.parse(sys.argv[1])" "$PLIST" 2>/dev/null; then
            say_err "Info.plist is not valid XML"
        else
            echo "  Info.plist XML OK"
        fi
    else
        echo "  Info.plist plutil OK"
    fi
    for key in CFBundleIdentifier CFBundleShortVersionString CFBundleVersion CFBundleName LSRequiresIPhoneOS NSAppTransportSecurity; do
        grep -q "<key>$key</key>" "$PLIST" || say_warn "Info.plist missing expected key: $key"
    done
    # ATS: Jellyfin servers are often plain http on the LAN; must allow it.
    if ! grep -A1 'NSAllowsArbitraryLoads' "$PLIST" | grep -q '<true/>'; then
        say_warn "NSAllowsArbitraryLoads is not true — http Jellyfin servers will be blocked"
    fi
fi

# --- 3. GoogleCast framework integrity ---
echo "-- Checking GoogleCast framework --"
if [ ! -d "$XCFW" ]; then
    say_err "missing $XCFW (download into Frameworks/ and re-add to pbxproj if needed)"
else
    [ ! -f "$XCFW/Info.plist" ] && say_err "GoogleCast.xcframework missing Info.plist"
    for slice in ios-arm64 ios-arm64_x86_64-simulator; do
        bin="$XCFW/$slice/GoogleCast.framework/GoogleCast"
        if [ -f "$bin" ]; then
            printf '  slice %-28s static binary OK\n' "$slice"
        else
            say_err "slice missing or not static: $bin"
        fi
    done
fi
if [ ! -f "$CAST_JSON" ]; then
    say_err "missing $CAST_JSON (GoogleCast download manifest)"
else
    if grep -qE '"type"[[:space:]]*:[[:space:]]*"static"|4\.8\.6' "$CAST_JSON"; then
        echo "  ChromeCastFramework.json OK (static 4.8.6)"
    else
        say_warn "ChromeCastFramework.json does not look like the static 4.8.6 manifest"
    fi
fi

# --- 4. Expected Chromecast source files ---
echo "-- Checking expected Chromecast source files --"
for f in "${CAST_SOURCES[@]}"; do
    [ -f "$ROOT/$f" ] || say_err "missing Cast source: $f"
done

# --- 5. Cast files that import GoogleCast must be guarded ---
# Files under the synced Shared/ dir compile into the tvOS target too, so any
# file that `import GoogleCast` without a guard breaks tvOS. Files that do not
# import the SDK (e.g. JellyfinCastReceiverID) are safe unguarded.
echo "-- Checking #if canImport(GoogleCast) guards --"
for f in "${CAST_SOURCES[@]}"; do
    file="$ROOT/$f"
    [ -f "$file" ] || continue
    if ! grep -q '^import GoogleCast' "$file"; then
        continue
    fi
    if ! grep -q '^#if canImport(GoogleCast)' "$file"; then
        say_err "$f imports GoogleCast but is not guarded by #if canImport(GoogleCast) — will break tvOS target"
        continue
    fi
    open=$(grep -c '^#if' "$file")
    close=$(grep -c '^#endif' "$file")
    if [ "$open" -ne "$close" ]; then
        say_err "$f unbalanced #if/#endif ($open vs $close)"
    fi
done

# --- 6. .cast wiring in shared/player/app code ---
echo "-- Checking .cast wiring --"
_vpt="$ROOT/Shared/Objects/VideoPlayerType/VideoPlayerType.swift"
if grep -q 'case .cast' "$_vpt"; then
    echo "  VideoPlayerType has .cast case"
else
    say_err "VideoPlayerType.swift missing 'case .cast'"
fi

if grep -q 'case .cast:' "$ROOT/Shared/Objects/VideoPlayerType/VideoPlayerType+Shared.swift"; then
    echo "  codecProfiles handles .cast"
else
    say_err "VideoPlayerType+Shared.swift codecProfiles missing .cast case"
fi

if grep -q 'case .cast:' "$ROOT/Shared/Coordinators/Navigation/NavigationRoute/NavigationRoute+Media.swift"; then
    echo "  NavigationRoute+Media handles .cast"
else
    say_err "NavigationRoute+Media.swift missing .cast case"
fi

if grep -q 'case .cast:' "$ROOT/Shared/Views/VideoPlayer/VideoPlayer.swift"; then
    echo "  VideoPlayer proxy switch handles .cast"
else
    say_err "VideoPlayer.swift proxy init missing .cast case"
fi

if grep -q 'GCKCastContext.setSharedInstanceWith' "$ROOT/Swiftfin/App/SwiftfinApp.swift"; then
    echo "  SwiftfinApp initializes GCKCastContext"
else
    say_warn "SwiftfinApp.swift does not call GCKCastContext.setSharedInstanceWith"
fi

# --- 7. Bundle ID override ---
echo "-- Checking bundle identifier override --"
n=$(grep -c "PRODUCT_BUNDLE_IDENTIFIER = $IOS_BUNDLE_ID" "$PBX" 2>/dev/null || true)
if [ "$n" -ge 2 ]; then
    echo "  iOS target uses $IOS_BUNDLE_ID"
else
    say_err "iOS target bundle id is not $IOS_BUNDLE_ID (pbxproj override lost?)"
fi

# --- 8. Known compile pitfalls in Cast code ---
echo "-- Checking Cast code for known compile pitfalls --"
while IFS= read -r f; do
    if grep -q 'jellyfinProviderBlue' "$f"; then
        say_err "renamed color in $f: .jellyfinProviderBlue (use .jellyfinPurple)"
    fi
    if grep -qE '\.timeInterval\b' "$f"; then
        say_err "removed API in $f: Duration.timeInterval (use .seconds)"
    fi
    if grep -qE 'withOptions:' "$f"; then
        say_warn "potential stale label in $f: withOptions: (Swift may have renamed to 'with:')"
    fi
    if grep -qE 'try!\|as!' "$f"; then
        say_warn "force-try / force-cast in $f — consider safe handling"
    fi
done < <(find "$ROOT/Shared/Services/Chromecast" "$ROOT/Shared/Components" \
         "$ROOT/Shared/Objects/MediaPlayerManager/MediaPlayerProxy" \
         "$ROOT/Shared/Objects/VideoPlayerType" -name '*.swift' 2>/dev/null | sort -u)

# --- Summary ---
echo ""
if [ "$errors" -gt 0 ]; then
    echo "== $errors error(s), $warn warning(s) — fix before pushing =="
    exit 1
elif [ "$warn" -gt 0 ]; then
    echo "== OK ($warn warning(s)) =="
    exit 0
else
    echo "== All checks passed =="
    exit 0
fi