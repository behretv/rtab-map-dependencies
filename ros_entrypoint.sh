#!/bin/bash
set -e

source_if_exists() {
  if [[ -f $1 ]]; then
    echo "Sourcing: $1"
    source "$1"
  fi
}

source_all_local_setup_files() {
  while line="" read -r file; do
    echo "Sourcing: ${file}"
    [[ -f ${file} ]] && source "${file}" || echo "NO file found!"
  done < <(find "$1" -wholename "*/install/local_setup.bash")
}

# Local setup files
apt_install_setup="/opt/ros/${ROS_DISTRO}/local_setup.bash"
merge_install_setup="/opt/ros/${ROS_DISTRO}/install/setup.bash"

# Print user
echo "User: $(whoami)"
echo "ROS apt root: ${apt_install_setup}"
echo "ROS merge root: ${merge_install_setup}"
echo "Catkin workspace: ${CATKIN_WS}"

# Source local ros setup filesfind
source_if_exists "${apt_install_setup}"
source_if_exists "${merge_install_setup}"
source_all_local_setup_files "${CATKIN_WS}"

exec "$@"
