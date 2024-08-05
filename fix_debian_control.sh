#!/bin/bash

CONTROL_FILE="debian/control"

# Fix dependency versioning in Build-Depends and Depends fields produced by bloom-generate
# e.g. `package=1.2.3` becomes `package (= 1.2.3)`
sed -i -E '
  /^(Build-Depends:|Depends:)/ {
    :a
    N
    /^(Build-Depends:|Depends:).*\n/!ba
    s/([a-zA-Z0-9.-]+)=([a-zA-Z0-9.-]+)/\1 (= \2)/g
  }
' "$CONTROL_FILE"
