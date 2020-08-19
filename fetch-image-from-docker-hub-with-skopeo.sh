#!/bin/sh
set -ue

IMAGE=$1
TAG=$2

skopeo copy docker://$IMAGE:$TAG dir:tmp.skopeo

mkdir -p v2/$IMAGE/manifests v2/$IMAGE/blobs

mv tmp.skopeo/manifest.json v2/$IMAGE/manifests/$TAG

for BLOB in $(
  jq -r .config.digest < v2/$IMAGE/manifests/$TAG
  jq -r .layers[].digest < v2/$IMAGE/manifests/$TAG
  )
do
  SHA=${BLOB#sha256:}
  mv tmp.skopeo/$SHA v2/$IMAGE/blobs/$BLOB
done

rm tmp.skopeo/version
rmdir tmp.skopeo

