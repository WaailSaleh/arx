#!/bin/sh
set -e
mkdir -p /pal/Package/Pal/Saved/SaveGames/0
exec /bin/sh /pal/Package/PalServer.sh "$@"