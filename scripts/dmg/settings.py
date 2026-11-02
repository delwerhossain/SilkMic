# dmgbuild settings for the SilkMic installer window (used by scripts/build-dmg.sh).
# dmgbuild writes the Finder layout directly, so it also works on headless CI runners.
import os.path

app = defines["app"]  # noqa: F821 - provided by dmgbuild -D app=...
here = os.path.abspath("scripts/dmg")  # dmgbuild runs from the repo root

format = "UDZO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = ["SilkMic.app"]

background = os.path.join(here, "background.tiff")  # 660x420 with a @2x layer
window_rect = ((200, 120), (660, 420))
icon_size = 112
text_size = 13
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
show_icon_preview = False
arrange_by = None
icon_locations = {
    os.path.basename(app): (170, 175),
    "Applications": (490, 175),
}
