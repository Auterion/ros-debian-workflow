#! /bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <package_dir> <version> [.deb files]"
    echo ""
    echo "Example: $0 px4-ros2-interface-lib/px4_ros2_cpp 0.0.100 path/to/ros-humble-px4-msgs_0.0.100-0jammy_arm64.deb"
    exit 1
fi

WORK_DIR=$(realpath "$1")
shift
VERSION="$1"
shift

# Replace version in package.xml
PACKAGE_XML="$WORK_DIR"/package.xml
[ ! -f "$PACKAGE_XML" ] && echo "File $PACKAGE_XML is missing" && exit 1
sed -i "s|<version>.*</version>|<version>$VERSION</version>|" "$PACKAGE_XML"

# Copy deb files to a temporary directory & update the package dependencies
DEB_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$DEB_TMP_DIR"' EXIT
for deb in "$@"; do
    cp "$deb" "$DEB_TMP_DIR"

    # Extract '<pkg-name>' from 'ros-<ros-version>-<pkg-name>_0.0.1-0jammy_arm64.deb'
    ros_pkg_version="$(basename "$deb" | sed -n 's/ros-\([^-]*\)-\(.*\)_.*.deb/\2/p')"
    ros_pkg=$(echo "$ros_pkg_version" | sed -n 's/\(.*\)_\([^_]*\)/\1/p')
    [ -z "$ros_pkg" ] && echo "Failed to extract ros package name from $deb" && exit 1

    # Replace <pkg-name>=<version> with just <pkg-name> in all rosdep files, since we inject this package.
    # The drawback is that the final .deb will not depend on the specific version of <pkg-name>.
    for rosdep in "$WORK_DIR"/rosdep-*.yaml; do
      sed -i "s|$ros_pkg=.*|$ros_pkg|" "$rosdep"
    done
done

docker run --rm -v "$WORK_DIR":/work -v "$DEB_TMP_DIR":/deb --platform linux/arm64 buildenv:current bash -c \
  'set -e; if [ -n "$(ls /deb/*.deb 2>/dev/null)" ]; then dpkg -i /deb/*.deb; fi; /build_package.sh'

echo "Done, built package is in $WORK_DIR/output"
