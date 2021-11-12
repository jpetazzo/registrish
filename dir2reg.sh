#!/bin/sh
set -ue

[ "$IMAGE" ] || {
  echo "Please export the IMAGE environment variable."
  exit 1
}

[ "$TAG" ] || {
  echo "Please export the TAG environment variable."
  exit 1
}

[ "$DIR" ] || {
  echo "Please export the DIR environment variable."
  exit 1
}

shamove() {
  SHA=$(sha256sum $1 | cut -d" " -f1)
  mv $1 v2/$IMAGE/$2/sha256:$SHA
}

mkdir -p v2/$IMAGE/manifests v2/$IMAGE/blobs
 
for FILE in $DIR/*; do
  case $FILE in
    */version)
      rm $FILE
      ;;
    *.manifest.json)
      shamove $FILE manifests
      ;;
    */manifest.json)
      cp $FILE v2/$IMAGE/manifests/$TAG
      shamove $FILE manifests
      ;;
    *)
      shamove $FILE blobs
      ;;
  esac
done
