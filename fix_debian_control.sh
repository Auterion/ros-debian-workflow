#!/bin/bash

# rosdep and bloom do not support dependency version pinning.
# Rationale: https://answers.ros.org/question/376259/rosdep-install-specific-version-of-dependencies/

# Although rosdep allows versions within package names (e.g., `package=1.2.3`)
# during dependency installation, bloom does not correctly process these
# versioned names when generating Debian metadata files.

# Namely the Debian control file should use the format `package (= 1.2.3)`
# for versioned dependencies. This script updates lines in the 'Build-Depends'
# and 'Depends' fields to match this format.

CONTROL_FILE="debian/control"

sed -i -E '
  /^(Build-Depends:|Depends:)/ {
    :a
    N
    /^(Build-Depends:|Depends:).*\n/!ba
    s/([a-z0-9.-]+)=([a-z0-9.-]+)/\1 (= \2)/g
  }
' "$CONTROL_FILE"
