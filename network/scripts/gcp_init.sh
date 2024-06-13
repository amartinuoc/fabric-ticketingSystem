#!/bin/bash

# Extract script name
script_name=$(basename "$0" | sed 's/\.[^.]*$//')
LOG_FILE="/tmp/gcp_init.txt"
LOCK_FILE="/tmp/gcp_init.lock"

# Log function
log() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - "$script_name" - $1"
}

# Check if the script is already running
if [ -e "$LOCK_FILE" ]; then
  exit 1
fi

log "SCRIPT STARTED" | tee -a "$LOG_FILE"

# Create a lock file to prevent multiple executions
touch "$LOCK_FILE"

# Set parameters
NETWORK_HOME="$HOME/fabric-ticketingSystem/network"
CONFIG_FILE="$NETWORK_HOME/config.properties"
BUCKET_NAME=$(grep "^GCP_BUCKET_NAME=" "$CONFIG_FILE" | cut -d'=' -f2)
MOUNT_POINT="$NETWORK_HOME/cloud_storage"
HOSTS_FILE="/etc/hosts"
GCS_HOSTS_FILE="$MOUNT_POINT/hosts.txt"
HOSTNAME=$(hostname)
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Create HOSTNAME_COMPLETE
case "$HOSTNAME" in
orderer)
  HOSTNAME_COMPLETE="orderer.uoctfm.com"
  ;;
peer0orgdev)
  HOSTNAME_COMPLETE="peer0.orgdev.uoctfm.com"
  ;;
peer0orgclient)
  HOSTNAME_COMPLETE="peer0.orgclient.uoctfm.com"
  ;;
peer0orgqa)
  HOSTNAME_COMPLETE="peer0.orgqa.uoctfm.com"
  ;;
*)
  log "Unrecognized hostname: $HOSTNAME" | tee -a "$LOG_FILE"
  log "Exiting" | tee -a "$LOG_FILE"
  exit 1
  ;;
esac

# Function to mount the GCS bucket
mount_gcs_bucket() {
  if ! mountpoint -q "$MOUNT_POINT"; then
    mkdir -p "$MOUNT_POINT"
    rm -rf "$MOUNT_POINT"/*
    gcsfuse "$BUCKET_NAME" "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
      log "Bucket mounted at '$MOUNT_POINT'" | tee -a "$LOG_FILE"
    else
      log "Error mounting the bucket" | tee -a "$LOG_FILE"
      exit 1
    fi
  fi
}

# Function to update the hosts.txt file in the bucket with the IP and the complete hostname
update_gcs_hosts_file() {
  # Check if the mount directory is mounted
  if ! mountpoint -q "$MOUNT_POINT"; then
    log "Error: $MOUNT_POINT is not mounted" | tee -a "$LOG_FILE"
    return 1
  fi

  # Check if the file in the bucket exists
  if [ ! -f "$GCS_HOSTS_FILE" ]; then
    log "$GCS_HOSTS_FILE does not exist. Creating an empty file." | tee -a "$LOG_FILE"
    touch "$GCS_HOSTS_FILE"
  fi

  # Find and update the line with the complete hostname
  if grep -q "$HOSTNAME_COMPLETE" "$GCS_HOSTS_FILE"; then
    sed -i "s/^.*$HOSTNAME_COMPLETE$/$LOCAL_IP $HOSTNAME_COMPLETE/" "$GCS_HOSTS_FILE"
    log "Updated $HOSTNAME_COMPLETE with IP $LOCAL_IP in $GCS_HOSTS_FILE" | tee -a "$LOG_FILE"
  else
    echo "$LOCAL_IP $HOSTNAME_COMPLETE" | tee -a "$GCS_HOSTS_FILE"
    log "Added $HOSTNAME_COMPLETE with IP $LOCAL_IP to $GCS_HOSTS_FILE" | tee -a "$LOG_FILE"
  fi
}

# Function to unmount the GCS bucket
unmount_gcs_bucket() {
  if mountpoint -q "$MOUNT_POINT"; then
    fusermount -u "$MOUNT_POINT"
    if [ $? -eq 0 ]; then
      log "Bucket unmounted from '$MOUNT_POINT'" | tee -a "$LOG_FILE"
    else
      log "Error unmounting the bucket" | tee -a "$LOG_FILE"
      return 1
    fi
  fi
}

mount_gcs_bucket
sleep 1
update_gcs_hosts_file
sleep 1
unmount_gcs_bucket

log "SCRIPT FINISH" | tee -a "$LOG_FILE"
