#!/bin/sh
# Points the examples at the termui package built from this checkout instead of the published one.
#
# The examples depend on the version on Ballerina Central, so that anyone who clones the repository can
# run them. CI (and a contributor testing a change) needs them to use the code in the working tree:
# first `cd ballerina && bal pack && bal push --repository=local`, then run this script from the root.
# It edits the examples' Ballerina.toml files, so do not commit the result.
set -eu

version=$(sed -n 's/^version = "\(.*\)"$/\1/p' ballerina/Ballerina.toml | head -n 1)
[ -n "$version" ] || { echo "could not read the package version" >&2; exit 1; }

for toml in examples/*/Ballerina.toml; do
  perl -0pi -e 's/(\[\[dependency\]\]\norg = "ayesha"\nname = "termui"\n)version = "[^"]*"\n(?:repository = "[^"]*"\n)?/$1version = "'"$version"'"\nrepository = "local"\n/' "$toml"
  echo "$toml -> termui $version from the local repository"
done
