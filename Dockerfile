# Use a pre-built SteamCMD image as our base
FROM cm2network/steamcmd:latest

# Set environment variables for the Palworld Server
# These can be overridden when you run the container
ENV APPID=2394010
ENV PALWORLD_DIR="/palworld"
ENV PORT=8211
ENV PLAYERS=16
ENV SERVER_NAME="My Baked-In Palworld Server"
ENV SERVER_PASSWORD="YourPassword"
ENV ADMIN_PASSWORD="YourAdminPassword"

# Create a directory for the server and make it the working directory
WORKDIR ${PALWORLD_DIR}

## THIS IS THE KEY STEP ##
# Run the SteamCMD installation during the image build process.
# This downloads the server files and "bakes" them into the image.
RUN steamcmd +force_install_dir ${PALWORLD_DIR} +login anonymous +app_update ${APPID} validate +quit

# Copy a simplified entrypoint script into the container
COPY ./entrypoint.sh .
RUN chmod +x ./entrypoint.sh

# Expose the game port
EXPOSE ${PORT}/udp

# Set the entrypoint to our custom script
ENTRYPOINT [ "./entrypoint.sh" ]