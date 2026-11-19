#!/bin/sh
# Points the examples at the termui package built from this checkout instead of the published one.
#
# The examples name no version of termui: their manifests only have a [package] section, so anyone who
# clones the repository can run them and Ballerina resolves the published release from Ballerina Central.
# CI (and a contributor testing a change) needs them to use the code in the working tree: first
# `cd ballerina && bal pack && bal push --repository=local`, then run this script from the root. It adds a
# dependency on the locally built version to each example's Ballerina.toml (replacing one it added before,
# so running it twice leaves one), and `git checkout examples` takes it away again. Do not commit the result.
set -eu

version=$(sed -n 's/^version = "\(.*\)"$/\1/p' ballerina/Ballerina.toml | head -n 1)
[ -n "$version" ] || { echo "could not read the package version" >&2; exit 1; }

for toml in examples/*/Ballerina.toml; do
  # Drop any termui dependency block (a header and the key lines under it), then add the local one.
  V="$version" perl -0pi -e '
    s{\n*\[\[dependency\]\]\n(?:(?!\[)[^\n]*\n?)*}{ $& =~ /name = "termui"/ ? "" : $& }ge;
    s/\n*\z/\n/;
    $_ .= "\n[[dependency]]\norg = \"ayesha\"\nname = \"termui\"\nversion = \"$ENV{V}\"\nrepository = \"local\"\n";
  ' "$toml"
  echo "$toml -> termui $version from the local repository"
done
