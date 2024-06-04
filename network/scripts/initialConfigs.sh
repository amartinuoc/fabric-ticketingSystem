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

    # Install Ggcsfuse
    export GCSFUSE_REPO=gcsfuse-$(lsb_release -c -s)
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/gcsfuse.gpg
    echo "deb [signed-by=/usr/share/keyrings/gcsfuse.gpg] https://packages.cloud.google.com/apt $GCSFUSE_REPO main" | sudo tee /etc/apt/sources.list.d/gcsfuse.list
    sudo apt update && sudo apt install gcsfuse -y
}

configure_docker() {
    # Start Docker service
    log "Starting Docker service..."
    sudo systemctl start docker

    # Enable Docker to start on system boot
    log "Enabling Docker service to start on system boot..."
    sudo systemctl enable docker

    # Add user to the Docker group
    log "Adding user to the Docker group..."
    sudo usermod -aG docker $USER
}

clone_repo() {
    if [ ! -d "$TARGET_DIR" ]; then
        log "Cloning repository..."
        git clone $REPO_URL "$TARGET_DIR"
    else
        log "The directory '$TARGET_DIR' already exists. Skipping clone."
    fi
}

mount_bucket() {

    cd $NETWORK_HOME || {
        log "Error navigating to directory '$NETWORK_HOME'"
        exit 1
    }

    # Create the cloud_storage directory if it does not exist
    mkdir -p $MOUNT_POINT

    # Mount the Google Cloud Storage bucket
    gcsfuse $BUCKET_NAME $MOUNT_POINT

    log "Bucket mounted at '$MOUNT_POINT'"

    # Configure automatic mount at system startup
    if ! grep -q "$MOUNT_POINT" /etc/fstab; then
        echo "$FSTAB_ENTRY" | sudo tee -a /etc/fstab
        log "Entry added to /etc/fstab for automatic mounting."
    else
        log "The entry for '$MOUNT_POINT' already exists in /etc/fstab."
    fi
}

# Install necessary packets
install_packets

# Configure service docker
configure_docker

# Clone the repository
clone_repo

# Mount the Google Cloud Storage bucket
mount_bucket
