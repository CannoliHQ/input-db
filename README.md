# Cannoli Input Database

Cannoli's curated controller mapping database. Every entry is a RetroArch-format
`.cfg` that has been verified on real hardware. The launcher fetches this repo at
build time; unknown pads fall back to the in-app setup wizard and Android defaults.

This is **not** a mirror of the community RetroArch autoconfig library.

## Layout

Files are grouped by vendor, one `.cfg` per controller or built-in handheld pad:

```
ayn/thor.cfg
8bitdo/pro2.cfg
sony/dualsense.cfg
```

Directory and file names are cosmetic; matching is done on the cfg's contents, not its path.

## Format

Standard RetroArch `input_*` autoconfig keys, plus a small set of Cannoli extensions.
See `ayn/thor.cfg` for a complete, annotated-by-example entry.

### Identity (how a pad is matched)

- `input_device`, `input_vendor_id`, `input_product_id` — the pad's reported identity.
- `cannoli_build_model` — **built-in handhelds only.** The device's exact
  `ro.product.model` (`Build.MODEL`), with spaces, e.g. `AYN Thor`. When present the
  entry is exclusive to that handheld model and outranks any vid/pid match. This is
  how sibling devices that share one pad identity (AYN Thor / Odin Portal / Odin 3
  and Retroid all report `Odin Controller` `8224:273`) are told apart.
  - Use the real `ro.product.model`, never the underscore-sanitized value that
    `adb devices -l` prints (`AYN_Thor`).

- `cannoli_device_aliases` — extra exact device names this same pad reports, separated by `|`.
  Android merges a pad's HID nodes into one InputDevice and names it after whichever node
  enumerated first, so one controller comes back as `GameSir-Pocket 1` on one connect and
  `GameSir-Pocket 1 Keyboard` on the next. List the alternates here.
  - Matching stays exact per name; this is a list of names, never a prefix or fuzzy rule.
  - An alias match ranks below an exact `input_device` match, so an entry that names the pad
    outright always beats one that only aliases it.
  - Capture the names, do not guess them: `adb shell dumpsys input` prints the merged device's
    name (`Device 10: GameSir-Pocket 1 Keyboard`), and reconnecting the pad shows which names it
    takes. RetroArch ignores this key; it scores vid/pid on its own.

### Legend (glyphs and confirm/back)

The legend is the physical face-button feel, kept separate from the keycode->action map.

- `cannoli_glyph_style` — one of `REDMOND` (Xbox letters), `PLUMBER` (Nintendo
  letters), `SHAPES` (PlayStation symbols).
- `cannoli_confirm_button` — the canonical button that acts as confirm, one of
  `BTN_SOUTH` / `BTN_EAST` / `BTN_NORTH` / `BTN_WEST`. Back is the opposite of confirm.

If a legend key is omitted, the launcher infers it (Sony vid -> `SHAPES`, otherwise the
`REDMOND` default). Set them explicitly for any pad whose feel is not plain Xbox.

### Bindings

Standard RetroArch keys. Face/shoulder buttons are Android keycodes; the d-pad uses hat
notation (`h0up`); triggers and sticks use axis notation, where the sign is the direction
and the number is a RetroArch analog *slot*, not an Android axis id (`+8`, `-0`).

- Axis numbers are RetroArch's compacted analog **slots**, not Android `MotionEvent`
  constants: left stick X/Y = `0`/`1`, right stick X/Y = `2`/`3`, `LTRIGGER` = `6`,
  `RTRIGGER` = `7`, `BRAKE` = `8`, `GAS` = `9`. The launcher captures the raw Android axis
  when you press the control and translates it to the slot on save, so pull the cfg off the
  device rather than hand-authoring these.
- Triggers: record only what the pad actually sends, which is not always both halves. A
  trigger may report an axis only, a keycode only, or both. **A declared button is not
  evidence.** The Retroid Pocket Nova lists `BTN_TL2` and `BTN_TR2` in its capability bitmap
  and never sends either: `getevent` across a full pull shows `ABS_BRAKE` ramping to full
  scale with no key event at all, while its L1 and R1 emit `BTN_TL` and `BTN_TR` normally in
  the same capture. So `input_l2_btn = "104"` on that pad is an inert line, and 104 and 105
  are just the Android constants, which is how they end up copied onto entries nobody
  measured. Add the digital keycode only once you have watched it fire.
  - To check: `adb shell getevent -lt /dev/input/eventN` and pull the trigger. Key events
    appear as `EV_KEY BTN_TL2 DOWN`; analog travel appears as `EV_ABS ABS_BRAKE` values.
  - The axis half is `input_l2_axis = "+8"` for a `BRAKE`-routed L2 (Nova) or `"+6"` for an
    `LTRIGGER`-routed one (Retroid Pocket Classic). Which slot a pad uses is its own
    business, so capture it, do not guess.
- Sticks: `input_l_x_plus_axis` / `_minus_axis` and the `l_y` / `r_x` / `r_y` pairs, on
  slots `0`-`3`.

Do not include per-instance keys in a database entry. `validate.sh` rejects them, so CI
catches a cfg pasted in unedited.

- `cannoli_user`, `cannoli_descriptor`, `cannoli_exclude_from_gameplay` belong to a single
  user's saved override, not the canonical mapping.
- `cannoli_menu_keycodes` is the menu button a user bound in the setup wizard. Cannoli tells
  RetroArch the menu key is unbound so its own menu never opens over the game, which is why
  the button is recorded here rather than in `input_menu_toggle_btn`. Deciding what a
  database entry should say is a judgement, not a line to copy across.
- `submission_build_model` and `submission_source_mask` are what the device could say about
  itself when the mapping was built, neither recoverable from the file later. The model is
  usually what `cannoli_build_model` wants for a built-in pad, but converting it is a human
  step, on purpose.

## Adding a pad

1. Map it on real hardware in Cannoli (press-to-bind captures the true keycodes/axes).
2. Pull the resulting cfg off the device.
3. Strip the per-instance keys listed above; confirm the identity and legend keys.
   Reconnect the pad a few times and add any alternate name it reports to `cannoli_device_aliases`.
4. Save it under `<vendor>/<device>.cfg` and run `./validate.sh`.
5. Open a PR noting the exact device and `ro.product.model` you verified against.

Only add an entry you have confirmed on the physical device.

## Validation

```
./validate.sh
```

Checks that every cfg has an identity, a valid glyph style and confirm button, that no alias
repeats its own `input_device` or another alias in the same file, and that no two entries claim
the same identity or alias. CI runs the same script on every push.
