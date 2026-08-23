# Companion for Home Assistant

[![CI](https://github.com/aurpelai/garmin-home-assistant-companion/actions/workflows/ci.yml/badge.svg)](https://github.com/aurpelai/garmin-home-assistant-companion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Garmin Connect IQ watch app for controlling and monitoring Home Assistant from your wrist. Open an area to toggle its lights, individually or as a group, and to read its temperature, humidity, and light level. More entity types are planned.

The app presents your home as floors and areas, following how you've organised them in Home Assistant, so an entity you haven't put in an area doesn't appear on the watch. Beyond that the app follows your setup: hidden entities stay hidden, and readings appear exactly as Home Assistant formats them.

Nothing to configure beyond your Home Assistant URL and a token — no YAML, no helper entities.

## Requirements

**Watch side**

- A supported Garmin watch: Fenix 7 (and S/X/Pro variants), Fenix 8 / 8 Pro / 8 Solar / E, Enduro 3, Venu 3 / 3S, Forerunner 265, or Vivoactive 5 / 6. See `manifest.xml` for the full product list.
- minApiLevel 5.0.0.
- On Bluetooth-only watches, Garmin Connect Mobile (GCM) must be installed, paired, and running in the background — it provides the network transport. WiFi/LTE watches can work standalone.

**Home Assistant side**

- HA reachable over **HTTPS with a publicly-trusted certificate**. Self-signed certificates are rejected by Connect IQ with no override, so a LAN-only HTTP instance will not work. The easiest path is [Home Assistant Cloud (Nabu Casa)](https://www.nabucasa.com/); the DIY alternative is a reverse proxy with a Let's Encrypt certificate.
- A long-lived access token for authentication.
- **Home Assistant 2024.4 or newer.** The app reads your floors, and the template functions for them were added in that release.

## User setup

1. Make sure your HA instance is reachable over HTTPS with a publicly-trusted cert (e.g. enable Nabu Casa remote access, or put HA behind a Let's Encrypt reverse proxy).
2. In Home Assistant, go to **Profile → Security → Long-Lived Access Tokens** and create a new token.
3. Install "Companion for Home Assistant" on your watch via Connect IQ.
4. Open the app's settings through the Garmin Connect Mobile app (Device → HA Companion → Settings), and enter your HA base URL and the token. **Paste the token — don't retype it**; a single mistyped character breaks auth.

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for setup and the PR process, and [WAYS-OF-WORKING.md](WAYS-OF-WORKING.md) for how the project runs.

## License

[MIT](LICENSE) © Antti Urpelainen
