# Companion for Home Assistant

[![CI](https://github.com/aurpelai/garmin-home-assistant-companion/actions/workflows/ci.yml/badge.svg)](https://github.com/aurpelai/garmin-home-assistant-companion/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A Garmin Connect IQ watch app for controlling and monitoring Home Assistant from your wrist. The first capability is lights — toggle them individually or by area — with more entity types and data display planned.

## Requirements

**Watch side**

- A supported Garmin watch: Fenix 7 (and S/X/Pro variants), Fenix 8 / 8 Pro / 8 Solar / E, Enduro 3, Venu 3 / 3S, Forerunner 265, or Vivoactive 5 / 6. See `manifest.xml` for the full product list.
- minApiLevel 5.0.0.
- On Bluetooth-only watches, Garmin Connect Mobile (GCM) must be installed, paired, and running in the background — it provides the network transport. WiFi/LTE watches can work standalone.

**Home Assistant side**

- HA reachable over **HTTPS with a publicly-trusted certificate**. Self-signed certificates are rejected by Connect IQ with no override, so a LAN-only HTTP instance will not work. The easiest path is [Home Assistant Cloud (Nabu Casa)](https://www.nabucasa.com/); the DIY alternative is a reverse proxy with a Let's Encrypt certificate.
- A long-lived access token for authentication.

## How it works

The app talks directly to HA's REST API from the watch via `Communications.makeWebRequest` — there's no custom backend and no companion app. Requests are authenticated with a Bearer token. To group lights by area with zero extra configuration (no YAML, no helper entities), the app POSTs a small Jinja template to HA's `/api/template` endpoint, which returns a JSON map of area name → light entity ids.

## User setup

1. Make sure your HA instance is reachable over HTTPS with a publicly-trusted cert (e.g. enable Nabu Casa remote access, or put HA behind a Let's Encrypt reverse proxy).
2. In Home Assistant, go to **Profile → Security → Long-Lived Access Tokens** and create a new token.
3. Install "Companion for Home Assistant" on your watch via Connect IQ.
4. Open the app's settings through the Garmin Connect Mobile app (Device → HA Companion → Settings), and enter your HA base URL and the token. **Paste the token — don't retype it**; a single mistyped character breaks auth.

## Roadmap / Status

Initial scaffold. Current (MVP) functionality: turn lights on/off or toggle them, individually or per Home Assistant area. Further features are expected on top of this base.

## Contributing

Contributions welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for setup and the PR process, and [WAYS-OF-WORKING.md](WAYS-OF-WORKING.md) for how the project runs.

## License

[MIT](LICENSE) © Antti Urpelainen
