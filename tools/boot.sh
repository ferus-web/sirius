#!/usr/bin/env bash

NIMFLAGS="--define:release --opt:speed --skipParentCfg:on --cc:clang --deepCopy:on"

fetchSubmodules() {
  echo ":: fetching submodules"
  git submodule update --init --recursive
}

installNeo() {
  echo ":: building neo"
  mkdir -p tools/bin

  cd tools/neo/
  nimble install --depsOnly
  nim c $NIMFLAGS --out:../bin/neo src/neo.nim 
}

fetchSubmodules
installNeo
