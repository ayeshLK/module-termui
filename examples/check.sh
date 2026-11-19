#!/bin/sh
# Compiles every example that a documentation page includes, against the termui version each one pins,
# and runs the tests of those that have them. CI runs this; run it from anywhere after installing Ballerina.
set -e
cd "$(dirname "$0")"
for dir in counter tutorial/step1-counter best-practices; do
    echo "== $dir"
    (cd "$dir" && bal build)
    if [ -d "$dir/tests" ]; then
        (cd "$dir" && bal test)
    fi
done
