# Companion for Home Assistant

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

## Development

### SDK setup

Install the Connect IQ SDK and either put its `bin/` directory on `PATH`, or point `CIQ_SDK` at the SDK root:

```sh
export CIQ_SDK="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/<version>"
```

A developer signing key is required to produce builds. Generate one once (git-ignored, handled via `openssl` under the hood):

```sh
make key
```

### Build, run, test

All Makefile targets accept `DEVICE=<id>` to override the default (`venu3`).

```sh
make build   # compile a debug build for DEVICE
make sim     # launch the Connect IQ simulator (leave running in another shell)
make run     # build + launch the app in the simulator
make test    # build + run unit tests (requires `make sim` running elsewhere)
make key     # generate developer_key.der (once)
make clean   # remove build output
```

### Project structure

```
manifest.xml            App metadata: id, products, permissions, min API level
monkey.jungle           Build source-set definition
Makefile                Build/run/test convenience targets

source/
  HaControllerApp.mc    App entry point
  config/
    Settings.mc         Reads HA URL + token from app Properties
  ha/
    HaClient.mc          Networking against the HA REST API
    ServiceCall.mc       Builds light service-call payloads
  model/
    AreaLightMap.mc      Pure parsing/derivation of area -> lights data
  ui/
    LoadingView.mc        Loading-state view
    LoadingDelegate.mc     Loading-state input delegate
    AreaMenu.mc            Area list menu
    LightMenu.mc           Light list menu (per area / individual)
    LightStore.mc          In-memory light/area state
    ErrorView.mc            Error display
  test/
    AreaLightMapTest.mc    Unit tests for area/light parsing
    ServiceCallTest.mc     Unit tests for service-call payload building

resources/
  strings/, settings/, drawables/   App strings, Connect IQ settings schema, icons

.github/workflows/ci.yml   CI pipeline
scripts/run-tests.sh        Headless simulator test runner used by CI
```

## Testing

Unit tests live in `source/test/*.mc`, written with Monkey C's `(:test)` annotations. They cover the pure logic that doesn't require a network: `AreaLightMap` parsing and service-call payload building. Networking itself isn't unit-testable in the Connect IQ test framework and is verified in the simulator or on-device instead.

Run tests locally:

```sh
make sim     # in one shell — leave running
make test    # in another shell
```

Or use the headless runner, which launches the simulator itself, builds and runs the tests, and returns a real exit code by parsing the console output for the `PASSED` summary (`monkeydo`'s own exit code is unreliable for test results):

```sh
scripts/run-tests.sh
```

## CI

`.github/workflows/ci.yml` runs on `ubuntu-latest` inside the
[`matco/connectiq-tester`](https://github.com/matco/connectiq-tester) container,
which bundles the Connect IQ SDK and runs a headless simulator via Xvfb — so the
whole build-and-test step runs on Linux with no Garmin login and no committed
signing key (the container generates a temporary self-signed certificate).

The **SDK version is pinned by the image tag**: `v2.8.0` bakes SDK 9.2.0, matching
what we develop against. Bumping the SDK is a deliberate tag bump — using
`:latest` would let it drift. No repository secrets are required, so CI also runs
on pull requests from forks.

## Roadmap / Status

Initial scaffold. Current (MVP) functionality: turn lights on/off or toggle them, individually or per Home Assistant area. Further features are expected on top of this base.

## License

[MIT](LICENSE) © Antti Urpelainen
