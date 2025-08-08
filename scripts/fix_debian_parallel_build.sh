#!/bin/bash

# Enable parallel builds for ROS packages
# This is not needed with debhelper 10+, but ROS (jazzy) still uses 9

RULES_FILE="debian/rules"

sed -i 's/dh_auto_build$/dh_auto_build --parallel/g' "$RULES_FILE"
