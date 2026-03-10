#! /bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <package_dir> <version> [.deb files]"
    echo ""
    echo "For a single package:"
    echo "  $0 px4-ros2-interface-lib/px4_ros2_cpp 0.0.100"
    echo ""
    echo "For multiple packages (comma-separated subdirectories):"
    echo "  $0 trellys 0.0.100 --packages trellys_msgs,trellys"
    echo ""
    echo "With pre-built .deb dependencies:"
    echo "  $0 px4-ros2-interface-lib/px4_ros2_cpp 0.0.100 path/to/dep.deb"
    exit 1
fi

WORK_DIR=$(realpath "$1")
shift
VERSION="$1"
shift

# Parse optional --packages flag and remaining .deb files
PACKAGES=""
DEB_FILES=()
while [ $# -gt 0 ]; do
    case "$1" in
        --packages)
            PACKAGES="$2"
            shift 2
            ;;
        *)
            DEB_FILES+=("$1")
            shift
            ;;
    esac
done

# Replace version in package.xml(s)
if [ -n "$PACKAGES" ]; then
    IFS=',' read -ra PKGS <<< "$PACKAGES"
    for pkg in "${PKGS[@]}"; do
        pkg=$(echo "$pkg" | xargs)
        PACKAGE_XML="$WORK_DIR/$pkg/package.xml"
        [ ! -f "$PACKAGE_XML" ] && echo "File $PACKAGE_XML is missing" && exit 1
        sed -i "s|<version>.*</version>|<version>$VERSION</version>|" "$PACKAGE_XML"
    done
else
    PACKAGE_XML="$WORK_DIR"/package.xml
    [ ! -f "$PACKAGE_XML" ] && echo "File $PACKAGE_XML is missing" && exit 1
    sed -i "s|<version>.*</version>|<version>$VERSION</version>|" "$PACKAGE_XML"
fi

# Copy deb files to a temporary directory & update the package dependencies
DEB_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$DEB_TMP_DIR"' EXIT
for deb in "${DEB_FILES[@]}"; do
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
  "set -e; if [ -n \"\$(ls /deb/*.deb 2>/dev/null)\" ]; then dpkg -i /deb/*.deb; fi; /scripts/build_package.sh \"$PACKAGES\""

echo "Done, built packages are in $WORK_DIR/output"
