#!/bin/bash
#
# Copyright (c) 2024, Auterion AG
# All rights reserved.
#

set -e

# If a Cloudsmith API key is provided, add the private auterion/apps repo
if [ -n "$CLOUDSMITH_API_KEY" ]; then
  echo "Adding auterion/apps Cloudsmith repository..."
  curl -u "token:${CLOUDSMITH_API_KEY}" -1sLf "https://dl.cloudsmith.io/basic/auterion/apps/setup.deb.sh" | bash
  apt-get update -qq
fi

# ROS_DISTRO is set by the ROS base image
DISTRO=${ROS_DISTRO}

# Packages to build: passed as comma-separated argument, default to "."
# For multi-package repos, list packages in dependency order (e.g. "msgs,core")
if [ $# -gt 0 ] && [ -n "$1" ]; then
  IFS=',' read -ra PACKAGES <<< "$1"
else
  PACKAGES=(".")
fi

# Collect and register all rosdep YAML files (at root and/or per-package)
ROSDEP_INDEX=0
for pkg in "${PACKAGES[@]}"; do
  pkg=$(echo "$pkg" | xargs)
  ROSDEP_FILE="/work/$pkg/rosdep-$DISTRO.yaml"
  if [[ -f "$ROSDEP_FILE" ]]; then
    echo "Found rosdep file: $ROSDEP_FILE"
    /scripts/update_rosdep_yaml.sh "$ROSDEP_FILE"
    /scripts/install_rosdeps.py "$ROSDEP_FILE"
    echo "yaml file://$ROSDEP_FILE" > "/etc/ros/rosdep/sources.list.d/99-local-${ROSDEP_INDEX}.list"
    ROSDEP_INDEX=$((ROSDEP_INDEX + 1))
  fi
done
if [ "$ROSDEP_INDEX" -eq 0 ]; then
  echo "No rosdep YAML files found."
fi

# Generate rosdep entries for all packages in the list so bloom can resolve
# inter-package dependencies (e.g. trellys depends on trellys_msgs)
if [ "${#PACKAGES[@]}" -gt 1 ]; then
  LOCAL_ROSDEP="/tmp/local-packages-rosdep.yaml"
  echo "# Auto-generated rosdep mappings for multi-package build" > "$LOCAL_ROSDEP"
  for pkg in "${PACKAGES[@]}"; do
    pkg=$(echo "$pkg" | xargs)
    PKG_NAME=$(grep -oP '<name>\K[^<]+' /work/$pkg/package.xml)
    # ROS package name to Debian package name: replace _ with -, prefix with ros-<distro>-
    DEB_NAME="ros-${DISTRO}-$(echo "$PKG_NAME" | tr '_' '-')"
    echo "${PKG_NAME}:" >> "$LOCAL_ROSDEP"
    echo "  ubuntu:" >> "$LOCAL_ROSDEP"
    echo "    - ${DEB_NAME}" >> "$LOCAL_ROSDEP"
  done
  echo "Generated local rosdep mappings:"
  cat "$LOCAL_ROSDEP"
  echo "yaml file://$LOCAL_ROSDEP" > "/etc/ros/rosdep/sources.list.d/99-local-multipackage.list"
fi

rosdep update --rosdistro=$DISTRO
mkdir -p /work/output

# Track built package names so rosdep can skip them
SKIP_KEYS=""

for pkg in "${PACKAGES[@]}"; do
  pkg=$(echo "$pkg" | xargs)  # trim whitespace

  echo "========================================="
  echo "Building package: $pkg"
  echo "========================================="

  cd /work/$pkg

  # Install any previously built packages as dependencies
  if [ -n "$(ls /work/output/*.deb 2>/dev/null)" ]; then
    dpkg -i /work/output/*.deb || true
    apt-get install -f -y
  fi

  SKIP_ARGS=""
  if [ -n "$SKIP_KEYS" ]; then
    SKIP_ARGS="--skip-keys=$SKIP_KEYS"
  fi
  rosdep install --from-paths . -y -v $SKIP_ARGS

  bloom-generate rosdebian
  /scripts/fix_debian_control.sh
  /scripts/fix_debian_parallel_build.sh

  export DEB_BUILD_OPTIONS="parallel=$(nproc) notest nocheck"
  fakeroot debian/rules clean
  fakeroot debian/rules binary

  # Collect built packages into output
  cp ../*.deb /work/output/ 2>/dev/null || true
  cp ../*.ddeb /work/output/ 2>/dev/null || true

  # Track this package's ROS name so subsequent rosdep calls skip it
  PKG_NAME=$(grep -oP '<name>\K[^<]+' /work/$pkg/package.xml)
  if [ -n "$SKIP_KEYS" ]; then
    SKIP_KEYS="$SKIP_KEYS $PKG_NAME"
  else
    SKIP_KEYS="$PKG_NAME"
  fi
done

echo "========================================="
echo "All packages built successfully:"
ls -la /work/output/
