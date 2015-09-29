#!/bin/bash

set -e -o pipefail

if [ "$COVERAGE" = true ]; then
    dub fetch doveralls
    dub test -b unittest-cov --compiler=${DC}
    dub run doveralls --compiler=${DC}
else
    dub test --compiler=${DC}
fi

if [ ! -z "$GH_TOKEN" ]; then
    DFLAGS='-c -o- -Df__dummy.html -Xfdocs.json' dub build
    dub fetch scod
    dub run scod -- filter --min-protection=Protected --only-documented docs.json
    dub run scod -- generate-html --navigation-type=ModuleTree docs.json docs
    pkg_path=$(dub list | sed -n 's|.*scod.*: ||p')
    rsync -ru "$pkg_path"public/ docs/

    cd docs
    git init
    git config user.name 'Travis-CI'
    git config user.email 'travis@nodemeatspace.com'
    git add .
    git commit -m 'Deployed to Github Pages'
    git push --force --quiet "https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}" master:gh-pages
fi
