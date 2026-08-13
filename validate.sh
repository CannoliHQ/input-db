#!/bin/sh
# Validate every controller cfg in the database.
# Checks identity, legend keys, absence of per-instance keys, and unique identities.
# Exits non-zero if anything fails. CI runs this on every push.

set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$SCRIPT_DIR"

errors=0
idfile=$(mktemp)
trap 'rm -f "$idfile"' EXIT

fail() {
    echo "  FAIL: $1"
    errors=$((errors + 1))
}

val() {
    # val <file> <key> -> the unquoted value, or empty
    grep -E "^$2[[:space:]]*=" "$1" 2>/dev/null | head -1 |
        sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'
}

cfgs=$(find . -name '*.cfg' | sort)
if [ -z "$cfgs" ]; then
    echo "No .cfg files found."
    exit 1
fi

for f in $cfgs; do
    echo "$f"

    device=$(val "$f" input_device)
    [ -n "$device" ] || fail "missing input_device"

    build_model=$(val "$f" cannoli_build_model)
    vid=$(val "$f" input_vendor_id)
    pid=$(val "$f" input_product_id)

    if [ -z "$build_model" ] && { [ -z "$vid" ] || [ -z "$pid" ]; }; then
        fail "no identity: needs cannoli_build_model, or input_vendor_id + input_product_id"
    fi

    glyph=$(val "$f" cannoli_glyph_style)
    case "$glyph" in
        "" | REDMOND | PLUMBER | SHAPES) ;;
        *) fail "invalid cannoli_glyph_style '$glyph' (REDMOND|PLUMBER|SHAPES)" ;;
    esac

    confirm=$(val "$f" cannoli_confirm_button)
    case "$confirm" in
        "" | BTN_SOUTH | BTN_EAST | BTN_NORTH | BTN_WEST) ;;
        *) fail "invalid cannoli_confirm_button '$confirm' (BTN_SOUTH|BTN_EAST|BTN_NORTH|BTN_WEST)" ;;
    esac

    for banned in cannoli_user cannoli_descriptor cannoli_exclude_from_gameplay; do
        if [ -n "$(val "$f" "$banned")" ]; then
            fail "per-instance key '$banned' does not belong in a database entry"
        fi
    done

    # Identity for duplicate detection: build_model wins, else vid/pid.
    if [ -n "$build_model" ]; then
        echo "model=$build_model	$f" >>"$idfile"
    elif [ -n "$vid" ] && [ -n "$pid" ]; then
        echo "vidpid=$vid:$pid	$f" >>"$idfile"
    fi
done

dups=$(cut -f1 "$idfile" | sort | uniq -d)
if [ -n "$dups" ]; then
    echo
    echo "Duplicate identities (two entries would match the same pad):"
    for d in $dups; do
        echo "  $d"
        grep -F "$d	" "$idfile" | cut -f2 | sed 's/^/    /'
    done
    errors=$((errors + 1))
fi

echo
if [ "$errors" -eq 0 ]; then
    echo "OK: $(echo "$cfgs" | wc -l | tr -d ' ') cfg(s) valid."
else
    echo "$errors problem(s) found."
    exit 1
fi
