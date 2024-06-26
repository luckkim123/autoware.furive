#!/usr/bin/env bash
# shellcheck disable=SC2086,SC2124

set -e

# Define terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
# BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR=$(readlink -f "$(dirname "$0")")
WORKSPACE_ROOT="$SCRIPT_DIR/../"
source "$WORKSPACE_ROOT/amd64.env"
if [ "$(uname -m)" = "aarch64" ]; then
    source "$WORKSPACE_ROOT/arm64.env"
fi

# Default values
option_no_nvidia=false
option_devel=false
option_headless=false
option_restart=false
option_ksm=false
MAP_PATH="/home/dgist/autoware_map"
WORKSPACE_PATH=""
USER_ID=""
WORKSPACE=""
CONTAINER_ID=""
DEFAULT_LAUNCH_CMD="ros2 launch autoware_launch autoware.launch.xml map_path:=/autoware_map vehicle_model:=sample_vehicle sensor_model:=sample_sensor_kit"

# Function to print help message
print_help() {
    echo -e "\n------------------------------------------------------------"
    echo -e "${RED}Note:${NC} The --map-path option is mandatory if not custom launch command given. Please provide exact path to the map files."
    echo -e "      Default launch command: ${GREEN}${DEFAULT_LAUNCH_CMD}${NC}"
    echo -e "------------------------------------------------------------"
    echo -e "${RED}Usage:${NC} run.sh [OPTIONS] [LAUNCH_CMD](optional)"
    echo -e "Options:"
    echo -e "  ${GREEN}--help/-h${NC}       Display this help message"
    echo -e "  ${GREEN}--map-path${NC}      Specify to mount map files into /autoware_map (mandatory if no custom launch command is provided)"
    echo -e "  ${GREEN}--no-nvidia${NC}     Disable NVIDIA GPU support"
    echo -e "  ${GREEN}--devel${NC}         Use the latest development version of Autoware"
    echo -e "  ${GREEN}--restart${NC}       Use the restart option"
    echo -e "  ${GREEN}--headless${NC}      Run Autoware in headless mode (default: false)"
    echo -e "  ${GREEN}--workspace${NC}     Specify to mount the workspace into /workspace"
    echo ""
}

# Parse arguments
parse_arguments() {
    while [ "$1" != "" ]; do
        case "$1" in
        --help | -h)
            print_help
            exit 1
            ;;
        --no-nvidia)
            option_no_nvidia=true
            ;;
        --devel)
            option_devel=true
            ;;
        --headless)
            option_headless=true
            ;;
        --restart)
            option_restart=true
            ;;
        --ksm)
            option_ksm=true
            ;;
        --workspace)
            WORKSPACE_PATH="$2"
            shift
            ;;
        --map-path)
            MAP_PATH="$2"
            shift
            ;;
        --*)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        -*)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
        *)
            LAUNCH_CMD="$@"
            break
            ;;
        esac
        shift
    done
}

# Set image and workspace variables
set_variables() {
    # Check if map path is provided for default launch command
    if [ "$MAP_PATH" == "" ] && [ "$LAUNCH_CMD" == "" ]; then
        print_help
        exit 1
    fi

    # Mount map path if provided
    MAP="-v ${MAP_PATH}:/autoware_map:ro"

    # Set workspace path if provided and login with local user
    if [ "$WORKSPACE_PATH" != "" ]; then
        USER_ID="-e LOCAL_UID=$(id -u) -e LOCAL_GID=$(id -g) -e LOCAL_USER=$(id -un) -e LOCAL_GROUP=$(id -gn)"
        WORKSPACE="-v ${WORKSPACE_PATH}:/workspace"
    fi

    # Set default launch command if not provided
    if [ "$LAUNCH_CMD" == "" ]; then
        if [ "$WORKSPACE_PATH" != "" ]; then
            LAUNCH_CMD="/bin/bash"
        else
            LAUNCH_CMD=${DEFAULT_LAUNCH_CMD}
        fi
    fi

    # Set image based on option
    if [ "$option_devel" == "true" ]; then
        IMAGE="ghcr.io/autowarefoundation/autoware-openadk:latest-devel"
        CONTAINER_ID="openadkit-devel"
    elif [ "$option_ksm" == "true" ]; then
        IMAGE="ghcr.io/autowarefoundation/autoware-openadk:latest-devel-ksm"
        CONTAINER_ID="openadkit-devel-ksm"
    else
        IMAGE="ghcr.io/autowarefoundation/autoware-openadk:latest-runtime"
        CONTAINER_ID="openadkit-runtime"
    fi
}

# Set GPU flag based on option
set_gpu_flag() {
    if [ "$option_no_nvidia" = "true" ]; then
        GPU_FLAG=""
    else
        GPU_FLAG="--gpus all"
        IMAGE=${IMAGE}-cuda
    fi
}

# Set X display variables
set_x_display() {
    MOUNT_X=""
    if [ "$option_headless" = "false" ]; then
        MOUNT_X="-e DISPLAY=$DISPLAY -v /tmp/.X11-unix/:/tmp/.X11-unix"
        xhost + >/dev/null
    fi
}

# Main script execution
main() {
    # Parse arguments
    parse_arguments "$@"
    set_variables
    set_gpu_flag
    set_x_display

    echo -e "${GREEN}\n-----------------------LAUNCHING CONTAINER-----------------------"
    echo -e "${GREEN}IMAGE:${NC} ${IMAGE}"
    echo -e "${GREEN}MAP PATH(mounted):${NC} ${MAP_PATH}:/autoware_map"
    echo -e "${GREEN}WORKSPACE(mounted):${NC} ${WORKSPACE_PATH}:/workspace"
    echo -e "${GREEN}LAUNCH CMD:${NC} ${LAUNCH_CMD}"
    echo -e "${GREEN}-----------------------------------------------------------------${NC}"

    # Launch the container
    set -x
    if [ "$option_restart" = "false" ]; then
        docker run -it --rm --net=host --name ${CONTAINER_ID} ${GPU_FLAG} ${USER_ID} ${MOUNT_X} \
            -e XAUTHORITY=${XAUTHORITY} -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR -e NVIDIA_DRIVER_CAPABILITIES=all -v /etc/localtime:/etc/localtime:ro \
            ${WORKSPACE} ${MAP} ${IMAGE} \
            ${LAUNCH_CMD}
    else
        docker run -it --restart always --net=host --name ${CONTAINER_ID} ${GPU_FLAG} ${USER_ID} ${MOUNT_X} \
            -e XAUTHORITY=${XAUTHORITY} -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR -e NVIDIA_DRIVER_CAPABILITIES=all -v /etc/localtime:/etc/localtime:ro \
            ${WORKSPACE} ${MAP} ${IMAGE} \
            ${LAUNCH_CMD}
    fi
}

# Execute the main script
main "$@"

