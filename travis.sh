#!/usr/bin/env bash

set -ueo pipefail

if [ ! -z "${COVERAGE:-}" ]; then
    dub fetch doveralls
    dub test -b unittest-cov
    dub run doveralls
else
    dub test
fi

if [ ! -z "${GH_TOKEN:-}" ]; then
    dub build -b ddox

    # push docs to gh-pages branch
    cd docs
    git init
    git config user.name 'Travis-CI'
    git config user.email '<>'
    git add .
    git commit -m 'Deployed to Github Pages'
    git push --force --quiet "https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}" master:gh-pages
fi
