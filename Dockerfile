# Arguments required for build stages
ARG BASE_IMAGE
ARG UBUNTU_VERSION

# Base image
FROM ${BASE_IMAGE} AS base

# Constant
ARG MAKEFLAGS="-j 6"
ARG RTI_NC_LICENSE_ACCEPTED=yes
ARG ROS_PACKAGE_PATH

# Arguments that are passed via --build-arg
ARG CATKIN_WS
ARG ROS_DISTRO
ARG UBUNTU_VERSION

# Extend scope
ENV CATKIN_WS="${CATKIN_WS}"\
  ROS_DISTRO="${ROS_DISTRO}"

# Global variables
# RPP - Expands to the set of packages found in then current environment (by searching the ROS_PACKAGE_PATH).
ENV ROS_PACKAGE_PATH="/opt/ros/${ROS_DISTRO}/install" \
  DEBIAN_FRONTEND=noninteractive \
  ROSINSTALL="ros2.${ROS_DISTRO}.rtabmap.rosinstall" \
  SKIP_KEYS="find_object_2d Pangolin libopencv-dev libopencv-contrib-dev libopencv-imgproc-dev python-opencv python3-opencv"\
  WORKSPACE=/workspace

# Validate global variables are set
SHELL ["/bin/bash", "-c", "-o", "pipefail"]
RUN if [[ -z "${ROS_DISTRO}" ]] ; then exit 1 ; else echo "${ROS_DISTRO}" ; fi
RUN if [[ -z "${ROS_PACKAGE_PATH}" ]] ; then exit 1 ; else echo "${ROS_PACKAGE_PATH}" ; fi
RUN if [[ -z "${CATKIN_WS}" ]] ; then exit 1 ; else mkdir -p -v "${CATKIN_WS}" ; fi

# Install debian dependencies
RUN apt-get clean && \
  apt-get update -y && \
  apt-get install -y --no-install-recommends \
  clang \
  cmake \
  g++ \
  gcc \
  git \
  google-mock \
  libboost-all-dev \
  libcairo2-dev \
  libceres-dev \
  libcurl4-openssl-dev \
  libeigen3-dev \
  libgflags-dev \
  libgmock-dev \
  libgoogle-glog-dev \
  libgtest-dev \
  liblua5.2-dev \
  libprotobuf-dev \
  libsuitesparse-dev \
  libtbb-dev \
  libusb-1.0-0-dev \
  libyaml-cpp-dev \
  locales \
  lsb-release \
  mysql-client \
  ninja-build \
  pciutils \
  protobuf-compiler \
  python3-apt \
  python3-dev \
  python3-mysqldb \
  python3-pandas \
  python3-pip \
  python3-rosdep \
  python3-sphinx \
  python3-wstool \
  stow \
  tree \
  && locale-gen en_US en_US.UTF-8 && \
  update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Generate the SLAM dependencies rosinstall file
WORKDIR "${CATKIN_WS}"
RUN source "${ROS_PACKAGE_PATH}/setup.bash" && \
  rosinstall_generator --deps --exclude RPP --rosdistro "${ROS_DISTRO}" \
  cartographer_ros \
  compressed_depth_image_transport \
  compressed_image_transport \
  diagnostic_updater \
  grid_map_ros \
  imu_filter_madgwick \
  laser_geometry \
  nav2_bringup \
  nav2_common \
  nav2_msgs \
  octomap \
  octomap_msgs \
  pcl_conversions \
  pcl_ros \
  realsense2_camera \
  realsense2_description \
  rviz_common \
  rviz_default_plugins \
  rviz_rendering \
  turtlebot3 \
  velodyne \
  > "${ROSINSTALL}" && \
  cat "${ROSINSTALL}" && \
  vcs import "${CATKIN_WS}" < "${ROSINSTALL}" && \
  find "${CATKIN_WS}" -name CMakeLists.txt -exec sed -i "s/Ceres::ceres/\${CERES_LIBRARIES}/g" {} \; && \
  find "${CATKIN_WS}" -name package.xml -exec sed -i "/libabsl-dev/d" {} \; && \
  find "${CATKIN_WS}" -name package.xml -exec sed -i "/xsimd/d" {} \; && \
  find "${CATKIN_WS}" -name package.xml -exec sed -i "/xtensor/d" {} \;

# Clone dependencies
RUN git config --global advice.detachedHead false && \
  git clone --depth 1 --branch 20230806_git https://github.com/RainerKuemmerle/g2o  /opt/g2o && \
  git clone --depth 1 --branch 4.1.1 https://github.com/borglab/gtsam.git /opt/gtsam && \
  git clone --depth 1 --branch 10.0.0 https://github.com/xtensor-stack/xsimd.git /opt/xsimd && \
  git clone --depth 1 --branch 0.24.7 https://github.com/xtensor-stack/xtensor.git /opt/xtensor && \
  git clone --depth 1 --branch 0.7.5 https://github.com/xtensor-stack/xtl.git /opt/xtl

FROM base AS ubuntu-20.04

# Clone dependencies
RUN git config --global advice.detachedHead false && \
  git clone --depth 1 --branch 20211102.0 https://github.com/abseil/abseil-cpp.git /opt/abseil-cpp && \
  git clone --depth 1 --branch master https://github.com/cartographer-project/cartographer.git /opt/cartographer

# Install abseil-cpp -> libabsl-dev
WORKDIR /opt/abseil-cpp
RUN cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
  -DCMAKE_INSTALL_PREFIX=/usr/local/stow/absl \
  -DCMAKE_CXX_STANDARD=14 && \
  ninja -C build && \
  ninja install -C build && \
  rm -rf build
WORKDIR /usr/local/stow
RUN stow absl

# Install cartographer
WORKDIR /opt/cartographer
RUN cmake -S . -B build -G Ninja \
  -DCMAKE_CXX_STANDARD=14 && \
  ninja -C build && \
  ninja install -C build && \
  rm -rf build

FROM base AS ubuntu-22.04

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends \
  libabsl-dev \
  && apt-get clean && \
  rm -rf /var/lib/apt/lists/*

FROM ubuntu-${UBUNTU_VERSION} AS final

# Install xsimd
WORKDIR /opt/xsimd
RUN cmake -S . -B build && \
  cmake --build build && \
  cmake --install build && \
  rm -rf build

# Install xtl
WORKDIR /opt/xtl
RUN cmake -S . -B build && \
  cmake --build build && \
  cmake --install build && \
  rm -rf build

# Install xtensor
WORKDIR /opt/xtensor
RUN cmake -S . -B build && \
  cmake --build build && \
  cmake --install build && \
  rm -rf build

WORKDIR /opt/g2o
RUN cmake -S . -B build \
  -DBUILD_WITH_MARCH_NATIVE=OFF \
  -DG2O_BUILD_APPS=OFF \
  -DG2O_BUILD_EXAMPLES=OFF \
  -DG2O_USE_OPENGL=OFF && \
  cmake --build build && \
  cmake --install build && \
  rm -rf build

# Install gtsam.org
WORKDIR /opt/gtsam
RUN cmake -S . -B build \
  -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
  -DGTSAM_USE_SYSTEM_EIGEN=ON && \
  cmake --build build && \
  cmake --install build && \
  rm -rf build

# Install ROS dependencies
WORKDIR "${CATKIN_WS}"
RUN source "${ROS_PACKAGE_PATH}/setup.bash" && \
  echo "--skip-keys ${SKIP_KEYS}" && \
  apt-get update && \
  rosdep install -y \
  --ignore-src \
  --from-paths "${CATKIN_WS}"  \
  --rosdistro "${ROS_DISTRO}" \
  --skip-keys "${SKIP_KEYS}" && \
  rm -rf /var/lib/apt/lists/* && \
  apt-get clean

# Install ROS packages
RUN source "${ROS_PACKAGE_PATH}/setup.bash" && \
  colcon build \
  --install-base "${ROS_PACKAGE_PATH}" \
  --merge-install \
  --base-paths "${CATKIN_WS}" \
  --ament-cmake-args " -Wno-dev" \
  --cmake-args -DCMAKE_CXX_FLAGS="-std=c++14" \
  && rm -rf \
  "${CATKIN_WS}/build" \
  "${CATKIN_WS}/log" \
  "${CATKIN_WS}/src" \
  "${CATKIN_WS}/*.rosinstall"

# Setup entrypoint
WORKDIR "${WORKSPACE}"
CMD ["/bin/bash"]
COPY ros_entrypoint.sh /tmp/ros_entrypoint.sh
ENTRYPOINT ["/tmp/ros_entrypoint.sh"]
