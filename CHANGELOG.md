# Changelog

All notable changes to this project are documented here.

This file is compiled from change fragments by [changie](https://changie.dev);
do not edit it by hand. Add a fragment with `changie new` in your PR instead.

## [v0.12.0] - 2026-09-04

### 🎉 New

- Double-tap a light or fan to adjust its brightness, color, or speed

### 🛠️ Technical

- Lights and fans carry their adjustable attributes and capabilities from Home Assistant, with optimistic updates while a change settles

## [v0.11.1] - 2026-09-02

### 🔧 Fixed

- Area and floor light indicators now update instantly when you toggle a light
- Areas with any entities are now shown

### 🛠️ Technical

- Derive light counts and summaries on the watch instead of fetching precomputed aggregates
- HaState stores toggleables by domain and ToggleableModel becomes the base class of LightModel and FanModel

### 🧹 Maintenance

- Cover the coordinator's refresh and toggle decisions with unit tests

## [v0.11.0] - 2026-09-02

### 🎉 New

- Fans can now be turned on and off from each area.

### 🔧 Fixed

- A humidity-only glance row now lines up on the left like every other status row instead of floating in the middle.

### 🛠️ Technical

- Collapsed the glance status-row types into one and moved item placement into the renderer.
- Lights and fans now share one toggleable model, row, and sort, and the service call derives its domain from the entity id.

## [v0.10.3] - 2026-08-31

### 🔧 Fixed

- An incorrect token no longer crashes the app or retries without end, settling on the error screen instead.

### 🛠️ Technical

- HaClient sends requests through a RequestGateway seam instead of calling Communications directly, and the redundant request-wrapper shims are folded away.
- The precomputed per-place counts and averages move out of HaState into a dedicated Aggregates module, leaving HaState as the entity core.
- The Screen interface splits into Perishable and Refreshable capabilities so each screen implements only what it truly does.
- Retries defer through a shared scheduler so the call stack unwinds between attempts instead of recursing.

## [v0.10.2] - 2026-08-26

### ✨ Improved

- The sensor reading icons are clearer and easier to tell apart.

### 🔧 Fixed

- Messages and errors are no longer drawn over the previous screen.
- Failed requests now show what went wrong instead of a generic error.
- Reconnecting to Home Assistant now shows the loading screen.
- Setup errors now name the actual problem.

## [v0.10.1] - 2026-08-26

### 🔧 Fixed

- The glance now properly picks up new data as it arrives instead of ignoring it.
- Changing the connection settings now clears the glance's data.

### 🛠️ Technical

- The glance redraws when new data arrives, and the background service is registered at app start.
- The minimum Connect IQ version is now 5.1.0 to allow redrawing from the background.

### 🧹 Maintenance

- Changelog fragments can record technical and maintenance work, not just user-facing changes
- A refinement to existing behaviour now implies a patch release instead of a minor one

## [v0.10.0] - 2026-08-26

### 🎉 New

- The glance now shows average temperature and humidity alongside the light status.
- The glance now refreshes in the background, even when the app is closed.

## [v0.9.0] - 2026-08-25

### 🎉 New

- A glance view shows phone connection and whole-home light status without opening the app

## [v0.8.0] - 2026-08-25

### ✨ Improved

- Temperature, humidity and illuminance readings now show an icon next to the value

## [v0.7.0] - 2026-08-25

### ✨ Improved

- A floor now indicates its light status with an icon instead of words

## [v0.6.0] - 2026-08-24

### 🎉 New

- Area cards show each light's status as a bulb icon — lit, off, or unavailable — instead of a plain dot

### ✨ Improved

- Sensor display precision arrives as its own payload field instead of being parsed from Home Assistant's formatted state string
- The page indicator is shown when there are two or more pages to flip through

### 🔧 Fixed

- A light group whose lights are all unavailable no longer sorts in among the individual lights

## [v0.5.3] - 2026-08-24

### 🔧 Fixed

- The app no longer gets stuck on the loading screen when part of your home fails to load.
- Tapping a light no longer makes it flash back to its old state before settling.

## [v0.5.2] - 2026-08-20

### 🔧 Fixed

- The app now re-registers with Home Assistant when the address or token changes.
- Each kind of request failure now recovers in the way that failure calls for.

## [v0.5.1] - 2026-08-18

### 🔧 Fixed

- The page indicator's more-pages markers are visible again — they were drawn in a colour that blended into the background.
- The error screen shows its select-to-retry button hint again, so retrying is discoverable.
- The app now recovers on its own after a Home Assistant restart.

## [v0.5.0] - 2026-08-17

### ✨ Improved

- **Area cards, floor cards and their menus stay consistent with each other** — toggles reach every light in scope, areas showing several sensors of one type report their mean, and empty areas are hidden.

### 🔧 Fixed

- **An unavailable or non-numeric sensor no longer corrupts an area's mean reading, and an undefined value no longer discards the whole payload** — per-value template guards replace the single float(0) default.
- **The page indicator follows the cards across a refresh** — a rebuild that adds or removes cards updates the dot count, and drops the indicator once too few pages remain.

## [v0.4.0] - 2026-08-09

### ✨ Improved

- **An unreadable response is named as such** — a reply that could not be read is no longer reported as an empty home.

### 🔧 Fixed

- **An unavailable sensor no longer blanks the whole app** — a sensor reporting no reading made Home Assistant abandon the entire state request, leaving the watch with nothing to show.
- **Unavailable sensors are left out of card readings and averages** — an offline sensor no longer reads as "unavailable °C" or drags a floor's average down.
- **A failing request no longer discards the Home Assistant registration** — only a dead webhook is re-registered, so an authentication or server error is reported instead of quietly replacing the registration.

## [v0.3.0] - 2026-08-08

### ✨ Improved

- **The page indicator scales with the screen** — its dots and spacing grow on larger, higher-resolution watches instead of staying the same pixel size everywhere.
- **The page indicator is now animated** — the indicator dots now fan out of view when they are not needed and re-appear when they are.
- **UX/UI improvements all around** — Including new fonts, a consistent 6-column layout, readability improvements

## [v0.2.0] - 2026-08-02

### 🎉 New

- **Turn a whole floor's lights on or off from one card** — selecting a floor opens an All Lights control that switches every light on that floor at once.

### ✨ Improved

- **Sensor names and light groups read more clearly** — sensors show the friendly name from Home Assistant, and a light group's row now says "Group • N Lights".
- **Cards show light status at a glance** — an area's lights appear as on/off/unavailable dots, a floor's sensor readings are averaged into one figure, and the cards follow the watch's own fonts and colors.
- **Floor cards summarize their lights** — a floor shows "All lights on", "Some lights on", "All lights off", or "No lights available" at a glance.

### 🔧 Fixed

- **The app now loads on real watches, not just the simulator** — home state is fetched over a channel Home Assistant returns as JSON, resolving the network error that left the app blank on-device.

## [v0.1.0] - 2026-07-29

### 🎉 New

- **Turn your Home Assistant lights on and off from your watch** — browse them by area, each under the name it has in Home Assistant.
- **Light state stays in sync with Home Assistant** — changes from a wall switch, automation, or another app show up, and toggling a group updates every light it controls.
- **Unavailable lights are called out, not hidden** — a light Home Assistant can't reach is labelled "Unavailable", can't be toggled, and sorts below the lights you can control.
- **Entities you've hidden in Home Assistant stay hidden on the watch** — a group's light count leaves them out, and an area or group whose lights are all hidden drops off the list too.
- **Opening an area shows its temperature, humidity, and light level** — read-only rows below the lights, each with the value exactly as Home Assistant formats it.
- **The home screen is now a floor-grouped card loop** — page through one floor or area at a time, with each floor introducing its rooms and summarizing its sensors, and press start on a room to open its lights and sensors.
