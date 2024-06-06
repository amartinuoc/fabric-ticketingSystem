#!/bin/bash

script_name=$(basename "$0" | sed 's/\.[^.]*$//')

REPO_URL="https://github.com/amartinuoc/fabric-ticketingSystem"
TARGET_DIR="$HOME/fabric-ticketingSystem"
NETWORK_HOME="$TARGET_DIR/network"
MOUNT_POINT="$NETWORK_HOME/cloud_storage"
BUCKET_NAME="bucket-tfm-test"
FSTAB_ENTRY="$BUCKET_NAME "$MOUNT_POINT" gcsfuse rw,allow_other,implicit_dirs,dir_mode=777,file_mode=777 0 0"

# Log function
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - "$script_name" - $1"
}

install_packets() {
    # Update package list
    log "Updating package list..."
    sudo apt update

    log "Installing some prerequisites..."

    # Install Git, cURL, Docker, Docker-compose, Go, Jq, and OpenJDK 11
    sudo apt install git curl docker.io docker-compose golang jq openjdk-11-jdk -y

    # Install gcsfuse
    export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s)
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/gcsfuse.gpg
    echo "deb [signed-by=/usr/share/keyrings/gcsfuse.gpg] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
    sudo apt update && sudo apt install gcsfuse -y
}

clone_repo() {
    if [ ! -d "$TARGET_DIR" ]; then
        log "Cloning repository..."
        git clone $REPO_URL "$TARGET_DIR"
    else
        log "The directory '$TARGET_DIR' already exists. Skipping clone."
    fi
}

configure_docker() {
    # Enable Docker to start on system boot
    log "Enabling Docker service to start on system boot..."
    sudo systemctl enable docker

    # Add user to the Docker group
    log "Adding user to the Docker group..."
    sudo usermod -aG docker $USER
}

create_systemd_service_gcp_init() {
    # Define the name of the current user
    local user=$(whoami)
    # Define the paths for the original and final scripts
    local pathOrigScript="scripts/gcp_init.sh"
    local pathFinScript="/usr/local/bin/gcp_init.sh"

    log "Creating Systemd service to init gcp on system boot..."

    # Copy the original script to the final location
    sudo cp $pathOrigScript $pathFinScript
    # Set execute permissions for the script
    sudo chmod +x $pathFinScript

    # Create the systemd service file
    cat <<EOF | sudo tee /etc/systemd/system/gcp_init.service >/dev/null
[Unit]
Description=GCP Initialization Script
After=network.target

[Service]
ExecStart=$pathFinScript
StandardOutput=journal
StandardError=journal
Restart=always
User=$user

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd services
    sudo systemctl daemon-reload

    # Enable the service to start on boot
    sudo systemctl enable gcp_init.service
}

# Install necessary packages
install_packets

# Clone the repository
clone_repo

# Configure Docker service
configure_docker

# Create the systemd service for GCP initialization
create_systemd_service_gcp_init

echo "Now you can restart the system"
