#!/bin/sh
for REPOSITORY in $(find v2 -type d -name manifests); do
  cd $REPOSITORY
  for TAG in *; do
    case $TAG in
      sha256:*) ;;
      *) cp $TAG sha256:$(sha256sum $TAG | awk '{print $1}') ;;
    esac
  done
  cd -
done
