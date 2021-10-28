#!/bin/bash
#
# Script to reset containerd
#

EXIT_SUCCESS=0
EXIT_FAILURE=1

# Display message
#
# Arguments:
#   an integer as exit code
#   a string as message
display_message()
{
    local EXIT_STATUS=$1
    local MESSAGE="$2"

    local MAX_SIZE=90
    local padding=""
    local result=""

    size=${#MESSAGE}
    loopSize=`expr ${MAX_SIZE} - ${size}`

    if [ ${size} -lt ${MAX_SIZE} ]; then
        for i in $(seq 0 ${loopSize})
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

    # Reset padding and result
    padding=""
    result=""

}

# Unmounts the mounted file
#
# Arguments:
#   a string containing mount point
#
umount_file()
{
    if [ "`cat /etc/mtab | grep -o ${MOUNT_POINT}`" == "${MOUNT_POINT}" ]; then
        sudo umount "${MOUNT_POINT}"
        display_message $? "Unmounting mount point ${MOUNT_POINT}"

        sudo rm -rf "${MOUNT_POINT}"
        display_message $? "Deleting mount point ${MOUNT_POINT}"
    else
        echo "Image not mounted at ${MOUNT_POINT} "
    fi
}

# Removes specimens directory
remove_specimens_directory()
{
    if [ -d "${SPECIMENS_DIR}" ]; then
        sudo rm -rf "${SPECIMENS_DIR}"
        display_message $? "Removing specimens directory ${SPECIMENS_DIR}"
    else
        echo "Specimens directory ${SPECIMENS_DIR} does not exist"
    fi
}

# Reset containerd setup on Debian/Ubuntu
debian_reset_containerd_setup()
{
    sudo apt -y remove ${PACKAGE_NAME} > /dev/null 2>&1
    display_message $? "Removing ${PACKAGE_NAME}"

    sudo apt -y purge ${PACKAGE_NAME} > /dev/null 2>&1
    display_message $? "Purging ${PACKAGE_NAME}"

    sudo rm -rf ${CONTAINERD_ROOT} > /dev/null 2>&1
    display_message $? "Deleting ${CONTAINERD_ROOT} directory"

    sudo apt -y install ${PACKAGE_NAME} > /dev/null 2>&1
    display_message $? "Installing ${PACKAGE_NAME}"
}

# Reset containerd setup on CentOS 7
centos_reset_containerd_setup()
{
    sudo yum -y remove ${PACKAGE_NAME} > /dev/null 2>&1
    display_message $? "Uninstalling ${PACKAGE_NAME}"

    sudo yum -y install ${PACKAGE_NAME} > /dev/null 2>&1
    display_message $? "Installing ${PACKAGE_NAME}"

    sed -i 's/#//g' ${CONTAINERD_CONFIG}
    display_message $? "Updating ${PACKAGE_NAME} config ${CONTAINERD_CONFIG}"

    sudo systemctl restart ${PACKAGE_NAME}.service
    display_message $? "Restarting ${PACKAGE_NAME} service"
}


# main
set -e

MOUNT_POINT="/mnt/container"
CONTAINERD_ROOT="/var/lib/containerd"
SPECIMENS_DIR="specimens"
PACKAGE_NAME="containerd"
CONTAINERD_CONFIG="/etc/containerd/config.toml"


umount_file
remove_specimens_directory

# Debian/Ubuntu
if [ -f /etc/lsb-release ]; then
    osname=`cat /etc/lsb-release | egrep -i 'debian|ubuntu'`
    if [ "${osname}" != "" ]; then
        debian_reset_containerd_setup
    fi
elif [ -f /etc/centos-release ]; then
    osname=`cat /etc/centos-release | grep -i 'centos'`
    if [ "${osname}" != "" ]; then
        centos_reset_containerd_setup
    fi
else
    echo "Unsupported OS"
fi
