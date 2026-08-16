# cannoli-input-db

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

Directory and file names are cosmetic; matching is done on the cfg's contents, not
its path.

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
- Analog triggers: bind both the digital keycode and the axis, e.g. `input_l2_btn = "104"`
  with `input_l2_axis = "+8"` (a `BRAKE`-routed L2, like the Retroid Pocket Nova) or `"+6"`
  (an `LTRIGGER`-routed one, like the Retroid Pocket Classic). Which slot a pad uses is its
  own business, so capture it, do not guess.
- Sticks: `input_l_x_plus_axis` / `_minus_axis` and the `l_y` / `r_x` / `r_y` pairs, on
  slots `0`-`3`.

Do not include per-instance keys in a database entry: `cannoli_user`,
`cannoli_descriptor`, and `cannoli_exclude_from_gameplay` belong to a single user's
saved override, not the canonical mapping.

## Adding a pad

1. Map it on real hardware in Cannoli (press-to-bind captures the true keycodes/axes).
2. Pull the resulting cfg off the device.
3. Strip the per-instance keys listed above; confirm the identity and legend keys.
4. Save it under `<vendor>/<device>.cfg` and run `./validate.sh`.
5. Open a PR noting the exact device and `ro.product.model` you verified against.

Only add an entry you have confirmed on the physical device.

## Validation

```
./validate.sh
```

Checks that every cfg has an identity, a valid glyph style and confirm button, and that
no two entries claim the same identity. CI runs the same script on every push.
