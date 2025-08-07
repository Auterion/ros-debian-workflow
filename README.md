# Reusable workflow for building Auterion public ROS2 Debian packages

## Example usage
```yaml
jobs:
  build:
    name: Build debian packages
    strategy:
      fail-fast: false
      matrix:
        platform:
          - platform: linux/arm64
            runner: "buildjet-4vcpu-ubuntu-2204-arm"
          - platform: linux/amd64
            runner: "buildjet-2vcpu-ubuntu-2204"
        distro:
          - ubuntu: jammy
            ros2: humble
          - ubuntu: noble
            ros2: jazzy
          - ubuntu: noble
            ros2: rolling

    uses: Auterion/ros-debian-workflow/.github/workflows/build-ros-debian.yml@main
    with:
      platform: ${{ matrix.platform.platform }}
      ubuntu-distro: ${{ matrix.distro.ubuntu }}
      ros2-distro: ${{ matrix.distro.ros2 }}
      runner: ${{ matrix.platform.runner }}
      source-prefix: px4_ros2_cpp # Optional, defaults to '.'
    secrets: inherit
```
This will also publish the packages to Cloudsmith if the `release` event is triggered.

## Local usage
Debian packages can be built locally.
To do so, first build the build environment docker container (only required once):
```bash
./build_env.sh
```

Then, build a package:
```bash
./build_pkg.sh <path/to/package> <version> [<.deb dependencies>]
```
For example:
```bash
./build_pkg.sh px4-ros2-interface-lib/px4_ros2_cpp 0.0.100 \
    ros-humble-px4-msgs_0.0.100-0jammy_arm64.deb
```
