#!/bin/bash

# Exit on any error
set -e

# Default configuration
DEFAULT_VERSION="7.20.2"
DEFAULT_DISK_SIZE="1" # 0 means no resize
TEMP_DIR="/root/temp"

echo "############## Start of Script ##############"

## Checking if temp dir is available...
if [ -d "$TEMP_DIR" ]; then
    echo "-- Temp directory exists: $TEMP_DIR"
else
    echo "-- Creating temp directory: $TEMP_DIR"
    mkdir -p "$TEMP_DIR"
fi

## Preparing for image download and VM creation!
echo ""
read -p "Please input CHR version to deploy [$DEFAULT_VERSION]: " version
version=${version:-$DEFAULT_VERSION}
echo "--> Using CHR version: $version"

# Check if image is available and download if needed
IMAGE_FILE="$TEMP_DIR/chr-$version.img"
if [ -f "$IMAGE_FILE" ]; then
    echo "-- CHR image is available: $IMAGE_FILE"
else
    echo "-- Downloading CHR $version image file..."
    cd "$TEMP_DIR"
    
    # Check if zip file exists to avoid re-downloading
    if [ ! -f "chr-$version.img.zip" ]; then
        echo "---------------------------------------------------------------------------"
        if ! wget --no-check-certificate "https://download.mikrotik.com/routeros/$version/chr-$version.img.zip"; then
            echo "ERROR: Failed to download CHR $version image file!"
            exit 1
        fi
        echo "---------------------------------------------------------------------------"
    fi
    
    echo "-- Extracting image file..."
    if ! unzip -o "chr-$version.img.zip"; then
        echo "ERROR: Failed to extract CHR $version image file!"
        exit 1
    fi
fi

if [ ! -f "$IMAGE_FILE" ]; then
    echo "ERROR: CHR image file not found after download/extraction: $IMAGE_FILE"
    exit 1
fi

## Show existing VM/CT IDs and let user choose
echo ""
echo "== Existing Virtual Machines (QM):"
qm list

echo ""
read -p "Please enter VM ID to use: " vmID

# Validate VM ID
if ! [[ "$vmID" =~ ^[0-9]+$ ]]; then
    echo "ERROR: VM ID must be a number!"
    exit 1
fi

# Check if VM ID is already used
if [ -f "/etc/pve/nodes/pve/qemu-server/$vmID.conf" ] || [ -f "/etc/pve/nodes/pve/lxc/$vmID.conf" ]; then
    echo "ERROR: VM ID $vmID is already used!"
    echo "Please choose a different VM ID."
    exit 1
fi

## Disk size configuration
echo ""
read -p "Please input additional disk size in GB (0 for no resize) [$DEFAULT_DISK_SIZE]: " imgsize
imgsize=${imgsize:-$DEFAULT_DISK_SIZE}
echo "--> Using disk size: $imgsize GB"

## Creating VM
echo ""
echo "-- Creating VM directory and image..."
mkdir -p "/var/lib/vz/images/$vmID"

# Convert image to qcow2 format
QCOW2_FILE="/var/lib/vz/images/$vmID/vm-$vmID-disk-1.qcow2"
echo "--> Converting image to qcow2 format..."
if ! qemu-img convert -f raw -O qcow2 "$IMAGE_FILE" "$QCOW2_FILE"; then
    echo "ERROR: Failed to convert image to qcow2 format!"
    exit 1
fi

# Resize image if requested
if [ "$imgsize" -ne "0" ]; then
    echo "--> Resizing image by +${imgsize}G..."
    if ! qemu-img resize "$QCOW2_FILE" "+${imgsize}G"; then
        echo "ERROR: Failed to resize image!"
        exit 1
    fi
fi

# Create the VM
echo ""
echo "-- Creating new CHR VM with ID: $vmID"
if ! qm create "$vmID" \
    --name "mikrotik-chr-$version" \
    --net0 virtio,bridge=vmbr0 \
    --bootdisk virtio0 \
    --ostype l26 \
    --memory 256 \
    --onboot no \
    --sockets 1 \
    --cores 1 \
    --virtio0 "local:$vmID/vm-$vmID-disk-1.qcow2"; then
    echo "ERROR: Failed to create VM!"
    exit 1
fi

echo ""
echo "############## End of Script ##############"
echo "SUCCESS: CHR VM $vmID created successfully!"
echo "You can start it with: qm start $vmID"
