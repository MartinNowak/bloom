#!/bin/bash

set -e -o pipefail

if [ "$COVERAGE" = true ]; then
    dub fetch doveralls --version=~master
    dub test -b unittest-cov --compiler=${DC}
    dub run doveralls --compiler=${DC}
else
    dub test --compiler=${DC}
fi

if [ ! -z "$GH_TOKEN" ]; then
    curl -fsSL http://releases.defenestrate.eu/harbored-mod-0.2.0/hmod-x86-64.tar.gz | tar -zxf -
    ./hmod src
    cd doc
    git init
    git config user.name "Travis-CI"
    git config user.email "travis@nodemeatspace.com"
    git add .
    git commit -m "Deployed to Github Pages"
    git push --force --quiet "https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}" master:gh-pages > /dev/null 2>&1
fi
