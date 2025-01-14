#!/bin/bash

# Description:
# This script takes a rosdep YAML file and replaces ROS package versions
# marked `=latest` with the latest version from apt-cache.
#
# Usage:
#   ./script_name.sh <path_to_rosdep_yaml>

YAML_FILE="$1"

if [[ -z "$YAML_FILE" || ! -f "$YAML_FILE" ]]; then
  echo "Usage: $0 <path_to_rosdep_yaml>"
  exit 1
fi

TEMP_FILE=$(mktemp)

while IFS= read -r line || [[ -n "$line" ]]; do
  # Check if the line has '=latest'
  if [[ "$line" =~ (ros-[a-z0-9-]+)=latest ]]; then
    PACKAGE_NAME="${BASH_REMATCH[1]}"
    
    # Get the latest version available via apt-cache
    LATEST_VERSION=$(apt-cache policy "$PACKAGE_NAME" | grep Candidate | awk '{print $2}')
    
    if [[ -z "$LATEST_VERSION" || "$LATEST_VERSION" == "(none)" ]]; then
      echo "Warning: No version found for $PACKAGE_NAME. Skipping."
      UPDATED_LINE="$line"
    else
      # Replace 'latest' with the actual version
      UPDATED_LINE="${line//=latest/=$LATEST_VERSION}"
      echo "Updated $PACKAGE_NAME to version $LATEST_VERSION"
    fi
  else
    # No change needed for other lines
    UPDATED_LINE="$line"
  fi
  
  # Write the updated line to the temp file
  echo "$UPDATED_LINE" >> "$TEMP_FILE"
done < "$YAML_FILE"

# Replace the original file with the updated content
mv "$TEMP_FILE" "$YAML_FILE"

echo "Update complete: $YAML_FILE"
