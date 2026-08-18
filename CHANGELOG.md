# Changelog

All notable changes to this project are documented here.

This file is compiled from change fragments by [changie](https://changie.dev);
do not edit it by hand. Add a fragment with `changie new` in your PR instead.

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
