# Device configurations

Why the top-level cards draw a "press to open" hint over the top-right button on
every watch, and the button facts behind that choice.

## Garmin's button layout

Garmin's button watches share one physical layout, and it's part of the brand's
"pick up any Garmin and you already know how to use it" promise. On a five-button
watch the buttons always map the same way:

| Position     | Role                                    |
| ------------ | --------------------------------------- |
| top-right    | start / select — the primary action     |
| bottom-right | back / lap                              |
| top-left     | up / previous                           |
| middle-left  | down / next (hold: menu)                |

Watches with fewer buttons drop the left column and keep the right: three-button
watches have start/select (top-right) and back (bottom-right) plus a menu key;
two-button watches keep only start/select and back.

The constant across all of them is **start/select at the top-right**. That is the
button a user presses to act on what's in front of them.

## Our device set

The numbers below are read from the local Connect IQ SDK device files
(`simulator.json` and `personality.mss` under
`~/Library/Application Support/Garmin/ConnectIQ/Devices/<device>/`), for the
products listed in `manifest.xml`. Re-derive them with the steps in
[Re-deriving this data](#re-deriving-this-data) when the device list changes.

| Buttons | Count | Devices                                                        |
| ------- | ----- | -------------------------------------------------------------- |
| 5       | 16    | enduro3, fenix7 family, fenix8 family, fenixe, fr265           |
| 3       | 3     | venu3, venu3s, vivoactive5                                     |
| 2       | 1     | vivoactive6                                                    |

Every device in the set is also a touchscreen, so touch is not a distinguishing
axis for us — button count is.

On all 20 devices the start/select key is the top-right button (verified from each
device's key geometry in `simulator.json`).

## Why we hint the top-right button

The cards show a hint icon telling the user they can press to open the entity
view. We want that hint over the start/select button, which is top-right on every
device.

The SDK exposes each button-position hint as a personality asset — an icon
(`system_icon_dark__hint_button_<position>`) paired with a location
(`system_loc__hint_button_<position>`). We use the **right-top** pair:

```xml
<bitmap id="SelectHint"
        personality="system_icon_dark__hint_button_right_top system_loc__hint_button_right_top" />
```

`hint_button_right_top` is the only hint that ships a real icon and location on
**every** device in our set with no exclusions, and it lands on the start/select
button on every one — so a single drawable works everywhere with no per-device
override.

The obvious-looking alternative, `hint_action_menu`, does not work universally: it
is excluded on vivoactive6 (see below). A `<bitmap>` referencing an excluded
personality asset produces no `Rez.Drawables` symbol for that device, which fails
the build at compile time (`Undefined symbol`). `hint_button_right_top` avoids
that because it exists everywhere.

## Personality hint exclusions in our set

These are observations across our device set, not documented Garmin rules. The
reasons are our reading of the evidence, marked as such.

- **`hint_action_menu` — excluded on vivoactive6 only.** vivoactive6 is the sole
  two-button device and has no dedicated menu button. It appears Garmin ships no
  action-menu hint there because there is no menu button to point at.
- **`hint_button_left_*` — excluded on the round touch models** (venu3, venu3s,
  vivoactive5). These are the three-button devices, which have no left-column
  buttons, so their left-button hints have nothing to point at.
- **`hint_button_right_middle` — excluded on every device in our set.** No current
  Garmin watch has a middle-right button. This alias appears to be reserved for
  another device family (e.g. cycling computers, which do have one) or a future
  layout — we do not use it.

## Re-deriving this data

Button counts come from the `keys` array in each device's `simulator.json`; the
start/select position comes from the `enter`-behavior key's location in the same
file. Hint icon and location availability come from each device's
`personality.mss` (`filename:` present vs. `exclude: true`). Point the lookup at
the device IDs in `manifest.xml` and re-run when that list changes.
