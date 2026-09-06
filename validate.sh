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

    # Aliases are extra exact names the same pad reports (Android renames a merged multi-node
    # device after whichever node enumerated first). Split on the pipe without a subshell, so a
    # failure here actually counts.
    aliases=$(val "$f" cannoli_device_aliases)
    if [ -n "$aliases" ]; then
        seen_aliases=""
        saved_ifs=$IFS
        IFS='|'
        for alias in $aliases; do
            IFS=$saved_ifs
            alias=$(printf '%s' "$alias" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            if [ -n "$alias" ]; then
                [ "$alias" != "$device" ] || fail "alias '$alias' repeats input_device"
                case "$seen_aliases" in
                    *"|$alias|"*) fail "duplicate alias '$alias'" ;;
                    *) seen_aliases="$seen_aliases|$alias|" ;;
                esac
                printf 'alias=%s\t%s\n' "$alias" "$f" >>"$idfile"
            fi
            IFS='|'
        done
        IFS=$saved_ifs
    fi

    # cannoli_menu_keycodes carries the menu button a user bound in the setup wizard. It exists
    # because input_menu_toggle_btn holds one keycode and cannot say "none" or "two", and because
    # Cannoli tells RetroArch the menu key is unbound so its own menu never opens over the game.
    # A submitted cfg therefore states its menu button here and nowhere else, and converting it to
    # input_menu_toggle_btn is a judgement a person makes, not a line to copy across.
    #
    # submission_* are what the device could say about itself when the mapping was built: the
    # handheld model and the pad's source mask, neither recoverable from the file afterwards.
    # They are captured deliberately under a prefix that matches nothing, so they reach a curator
    # without pinning an unverified profile to a handheld model on the way.
    for banned in cannoli_user cannoli_descriptor cannoli_exclude_from_gameplay \
                  cannoli_menu_keycodes submission_build_model submission_source_mask; do
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
    printf '%s\n' "$dups" | while IFS= read -r d; do
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
