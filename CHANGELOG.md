# Changelog

All notable changes to this project are documented here.

This file is compiled from change fragments by [changie](https://changie.dev);
do not edit it by hand. Add a fragment with `changie new` in your PR instead.
## [v0.2.0] - 2026-08-02
### 🎉 New
- **Turn a whole floor's lights on or off from one card** — selecting a floor opens an All Lights control that switches every light on that floor at once.
### ✨ Improved
- **Sensor names and light groups read more clearly** — sensors show the friendly name from Home Assistant, and a light group's row now says "Group • N Lights".
- **Cards show light status at a glance** — an area's lights appear as on/off/unavailable dots, a floor's sensor readings are averaged into one figure, and the cards follow the watch's own fonts and colors.
- **Floor cards summarize their lights** — a floor shows "All lights on", "Some lights on", "All lights off", or "No lights available" at a glance.
### 🔧 Fixed
- **The app now loads on real watches, not just the simulator** — home state is fetched over a channel Home Assistant returns as JSON, resolving the network error that left the app blank on-device.## [v0.1.0] - 2026-07-29
### 🎉 New
- **Turn your Home Assistant lights on and off from your watch** — browse them by area, each under the name it has in Home Assistant.
- **Light state stays in sync with Home Assistant** — changes from a wall switch, automation, or another app show up, and toggling a group updates every light it controls.
- **Unavailable lights are called out, not hidden** — a light Home Assistant can't reach is labelled "Unavailable", can't be toggled, and sorts below the lights you can control.
- **Entities you've hidden in Home Assistant stay hidden on the watch** — a group's light count leaves them out, and an area or group whose lights are all hidden drops off the list too.
- **Opening an area shows its temperature, humidity, and light level** — read-only rows below the lights, each with the value exactly as Home Assistant formats it.
- **The home screen is now a floor-grouped card loop** — page through one floor or area at a time, with each floor introducing its rooms and summarizing its sensors, and press start on a room to open its lights and sensors.