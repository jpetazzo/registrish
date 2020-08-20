#!/bin/sh
set -ue

IMAGE=$1
TAG=$2

curl localhost:5000 || docker run -d -p 5000:5000 registry:2
REGISTRY=localhost:5000

docker pull $IMAGE:$TAG
docker tag $IMAGE:$TAG $REGISTRY/$IMAGE:$TAG
docker push $REGISTRY/$IMAGE:$TAG

MANIFEST_CONTENT_TYPE=application/vnd.docker.distribution.manifest.v2+json

mkdir -p v2/$IMAGE/manifests v2/$IMAGE/blobs

curl -sS -H "Accept: $MANIFEST_CONTENT_TYPE" $REGISTRY/v2/$IMAGE/manifests/$TAG > v2/$IMAGE/manifests/$TAG

for BLOB in $(
  jq -r .config.digest < v2/$IMAGE/manifests/$TAG
  jq -r .layers[].digest < v2/$IMAGE/manifests/$TAG
  )
do
  curl -sS $REGISTRY/v2/$IMAGE/blobs/$BLOB > v2/$IMAGE/blobs/$BLOB
done
