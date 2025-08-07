#!/bin/bash
set -e

# This script no longer needs to install anything.
# It just launches the pre-installed server.

# Navigate to the server directory
cd ${PALWORLD_DIR}

# Construct the server arguments
ARGS="-port=${PORT} -players=${PLAYERS} EpicApp=PalServer"

# Only add server name and password if they are set
if [ -n "${SERVER_NAME}" ]; then
    ARGS="${ARGS} -servername=\"${SERVER_NAME}\""
fi

if [ -n "${SERVER_PASSWORD}" ]; then
    ARGS="${ARGS} -serverpassword=\"${SERVER_PASSWORD}\""
fi

# Launch the server using "exec" to make it the main process
echo "Starting PalServer with args: ${ARGS}"
eval exec "./PalServer.sh ${ARGS}"