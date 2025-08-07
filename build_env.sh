platform="linux/arm64"
ros2_distro="humble"
ubuntu_distro="jammy"
# ros2_distro="foxy"
# ubuntu_distro="focal"
# ros2_distro="iron"
# ubuntu_distro="noble"
# ros2_distro="rolling"
# ubuntu_distro="noble"


docker build . -f Dockerfile.debian-buildenv \
    --platform $platform \
    --build-arg="ROS2_DISTRO=$ros2_distro" \
    --build-arg="UBUNTU_DISTRO=$ubuntu_distro" \
    -t buildenv:current
