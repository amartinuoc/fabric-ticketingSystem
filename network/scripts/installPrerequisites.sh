#!/bin/bash

# Log function
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

log "Starting installation script..."

# Update package list
log "Updating package list..."
sudo apt update

# Install Git, cURL, Docker, Docker-compose, Go, Jq, and OpenJDK 11
log "Installing prerequisites..."
sudo apt install git curl docker.io docker-compose golang jq openjdk-11-jdk -y

# Start Docker service
log "Starting Docker service..."
sudo systemctl start docker

# Enable Docker to start on system boot
log "Enabling Docker service to start on system boot..."
sudo systemctl enable docker

# Add user to the Docker group
log "Adding user to the Docker group..."
sudo usermod -aG docker $USER

log "Installation complete."


