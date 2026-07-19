#!/usr/bin/env python3
"""Generate per-size launcher icon resource folders from one master SVG.

Pattern borrowed from the GarminHomeAssistant app: keep a single master vector
icon and emit one `resources-launcher-<N>/` bucket per distinct launcher icon
size our target devices need (icons are square, so one dimension names the
bucket). Each bucket contains the same SVG with only its root width/height
rewritten, plus a drawables.xml declaring LauncherIcon.

Connect IQ does not auto-scale a single launcher icon per device, and launcher
size does not map cleanly to screen resolution (e.g. venu3s/vivoactive5/
vivoactive6 are all 390x390 but need 70/56/54 px icons), so per-size buckets
wired per-device in monkey.jungle are the correct approach — device-id folders
would mean duplicated assets, and resolution qualifiers collide.

Run from the repo root:  python3 scripts/generate_launcher_icons.py
"""

import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
MASTER = REPO / "icons" / "launcher_master.svg"

# Distinct launcher icon sizes across all target devices (see monkey.jungle for
# the device -> size mapping). Square, so width == height.
SIZES = [40, 54, 56, 60, 65, 70]

DRAWABLES_XML = (
    '<?xml version="1.0" encoding="UTF-8"?>\n'
    "<drawables>\n"
    '    <bitmap id="LauncherIcon" filename="launcher.svg" />\n'
    "</drawables>\n"
)


def main() -> None:
    master = MASTER.read_text()
    for size in SIZES:
        # Rewrite only the root <svg> width/height; viewBox is untouched so the
        # artwork scales cleanly.
        svg = re.sub(r'width="\d+"', f'width="{size}"', master, count=1)
        svg = re.sub(r'height="\d+"', f'height="{size}"', svg, count=1)

        folder = REPO / f"resources-launcher-{size}" / "drawables"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "launcher.svg").write_text(svg)
        (folder / "drawables.xml").write_text(DRAWABLES_XML)
        print(f"wrote resources-launcher-{size}/")


if __name__ == "__main__":
    main()
