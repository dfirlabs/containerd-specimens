#!/bin/bash
#
# Script to generate containerd test files
# 
# This script requires Linux with dd, mkfs.ext4, containerd

EXIT_SUCCESS=0;
EXIT_FAILURE=1;

# Display message
#
# Arguments:
#   an integer containing exit code
#   a string containing message to display
#
display_message()
{
    local EXIT_STATUS=$1
    local MESSAGE="$2"

    local MAX_SIZE=90
    local padding=""
    local result=""

    size=${#MESSAGE}
    paddingSize=`expr ${MAX_SIZE} - ${size}`

    if [ ${paddingSize} -gt 0 ]; then
        for i in $(seq 0 ${paddingSize})
        do
            padding+=" "
        done
    fi

    if [ ${EXIT_STATUS} -eq ${EXIT_SUCCESS} ]; then
        result="[   OK   ]"
    else
        result="[ FAILED ]"
    fi

    echo "${MESSAGE} ${padding} ${result}"
}

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
assert_availability_binary()
{
    local BINARY=$1;

    which ${BINARY} > /dev/null 2>&1;
    if test $? -ne ${EXIT_SUCCESS};
    then
        echo "Missing binary: ${BINARY}";
        echo "";

        exit ${EXIT_FAILURE};
    fi
}

# Creates a containerd container
#
# Arguments:
#    a string identifying containerd namespace
#    a string identifying containerd image path
#    a string identifying containerd container name
#
create_containerd_container()
{
    local NAMESPACE="$1";
    local IMAGE_PATH="$2";
    local CONTAINER_NAME="$3";

    # Check container namespace exits
    ns=`sudo ctr namespaces list | grep ${NAMESPACE} | tr -d '[:space:]'`;
    if [ "$ns" != "${NAMESPACE}" ]; then
        sudo ctr namespace create ${NAMESPACE} > /dev/null 2>&1;
        display_message $? "Creating namespace ${NAMESPACE}"
    fi

    # Check containerd image name
    in=`sudo ctr -n ${NAMESPACE} images list | grep ${IMAGE_PATH} | awk '{print $1}' | tr -d '[:space:]'`;
    if [ "${in}" != "${IMAGE_PATH}" ]; then
        sudo ctr -n ${NAMESPACE} images pull ${IMAGE_PATH} > /dev/null 2>&1;
        display_message $? "Pulling image ${IMAGE_PATH} with namespace ${NAMESPACE}"
    fi

    # Check container name
    cn=`sudo ctr -n ${NAMESPACE} containers list | grep ${CONTAINER_NAME} | awk '{print $1}' | tr -d '[:space:]'`;
    if [ "${cn}" != ${CONTAINER_NAME} ]; then
        sudo ctr -n ${NAMESPACE} container create ${IMAGE_PATH} ${CONTAINER_NAME} > /dev/null 2>&1;
        display_message $? "Creating container ${CONTAINER_NAME} with namespace ${NAMESPACE}"
    fi

    sleep 5
}

# Create test file entries
#
# Arguments:
#   a string containing the mount point of the image file
#
create_test_file_entries()
{
    MOUNT_POINT=$1;

    sudo mkdir -p ${MOUNT_POINT}/var/lib;

    # Create test containers
    create_containerd_container default docker.io/library/nginx:latest nginx-specimen
    sleep 2

    create_containerd_container dfirlabs docker.io/library/redis:latest redis-specimen
    sleep 2

    # Copy containerd files
    sudo cp -r /var/lib/containerd ${MOUNT_POINT}/var/lib
    display_message $? "Copying /var/lib/containerd to ${MOUNT_POINT}/var/lib"
}

# Creates a test image file
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.ext4
#
create_test_image_file()
{
    IMAGE_FILE=$1;
    IMAGE_SIZE=$2;
    SECTOR_SIZE=$3;
    shift 3;
    local ARGUMENTS=("$@");

    sudo dd if=/dev/zero of=${IMAGE_FILE} bs=${SECTOR_SIZE} count=$(( ${IMAGE_SIZE} / ${SECTOR_SIZE})) 2> /dev/null;
    display_message $? "Creating disk image ${IMAGE_FILE}"

    sudo mkfs.ext4 -F -q ${ARGUMENTS[@]} ${IMAGE_FILE};
    display_message $? "Making EXT4 file system (${IMAGE_FILE})"
}

# Creates a test image file with file entries
#
# Arguments:
#   a stirng containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for mkfs.ext4
#
create_test_image_with_file_entries()
{
    IMAGE_FILE=$1;
    IMAGE_SIZE=$2;
    SECTOR_SIZE=$3;
    shift 3;
    local ARGUMENTS=("$@");

    create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]};

    sudo mount -o loop,rw ${IMAGE_FILE} ${MOUNT_POINT};
    display_message $? "Mounting ${IMAGE_FILE} to ${MOUNT_POINT} in Read/Write mode"

    sudo chown ${USERNAME}:${GROUPNAME} ${MOUNT_POINT};

    create_test_file_entries ${MOUNT_POINT};

    sudo umount ${MOUNT_POINT};
    display_message $? "Unmounting ${MOUNT_POINT}"

    sudo mount -o loop,ro ${IMAGE_FILE} ${MOUNT_POINT};
    display_message $? "Mounting ${IMAGE_FILE} to ${MOUNT_POINT} in ReadOnly mode"
}


assert_availability_binary dd;
assert_availability_binary mkfs.ext4;
assert_availability_binary ctr;

set -e;

USERNAME="root";
GROUPNAME="root";

SPECIMENS_PATH="specimens";

mkdir -p ${SPECIMENS_PATH};

MOUNT_POINT="/mnt/container";

sudo mkdir -p ${MOUNT_POINT};

# Need at least 4 GB
IMAGE_SIZE=$(( 1 * 1024 * 1024 * 1024 ));
SECTOR_SIZE=512

# Create a EXT4 file system
create_test_image_with_file_entries "${SPECIMENS_PATH}/ext4.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-L containerd_test";

exit ${EXIT_SUCCESS};
