#!/bin/sh
# Titanium session entry — started by TitaniumLogin after X is up.
# Installed conceptually to /usr/lib/titanium/session.sh
#
# Keep this script tiny: wallpaper companion, then exec the WM.

titaniumbg &
exec titaniumwm
