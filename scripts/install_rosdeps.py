#!/usr/bin/env python3

# Usage: python3 install_rosdeps.py path/to/rosdep.yaml

# This script installs system dependencies listed in a rosdep YAML file using APT.
# It should be run before `rosdep install` to ensure specific package versions are installed.

# Why it's needed:
# `rosdep` only checks if a required package is present, not whether the correct version is installed.
# APT, however, will detect version mismatches and prevent incompatible packages from being installed.

# This script helps catch issues like version conflicts between dependencies. For example:
#   pkg_A depends on pkg_C (v1)
#   pkg_B depends on pkg_C (v2)
#   pkg_A depends on pkg_B
# In this case, it's impossible to satisfy all dependencies correctly. This script will surface such conflicts.

# Note:
# APT can't automatically resolve these version mismatches.
# It's the package maintainer's responsibility to ensure that all pinned dependency versions are compatible.


import sys
import yaml
import subprocess

def run_command(command):
    process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    for stdout_line in iter(process.stdout.readline, ""):
        print(stdout_line, end="")
    for stderr_line in iter(process.stderr.readline, ""):
        print(stderr_line, end="")

    process.stdout.close()
    process.stderr.close()
    return_code = process.wait()

    if return_code != 0:
        print(f"Error executing command: {command}")
        sys.exit(return_code)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 install_rosdeps.py path/to/rosdep.yaml")
        sys.exit(1)

    file_path = sys.argv[1]

    print(f"Reading dependencies from {file_path}")

    with open(file_path, 'r') as f:
        data = yaml.safe_load(f)

    packages = set()

    for key, val in data.items():
        if isinstance(val, dict) and 'ubuntu' in val:
            ubuntu_deps = val['ubuntu']
            if isinstance(ubuntu_deps, str):
                packages.add(ubuntu_deps)
            elif isinstance(ubuntu_deps, list):
                packages.update(ubuntu_deps)

    print(f"Manually installing the following packages via APT, before rosdep scan:")
    for package in packages:
        print(f"  - {package}")

    run_command("apt update")
    run_command(f"apt install -y {' '.join(sorted(packages))}")

if __name__ == "__main__":
    main()
