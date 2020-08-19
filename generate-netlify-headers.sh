#!/bin/sh
set -ue

(
echo "/*/manifests/*"
echo "  Content-Type: application/vnd.docker.distribution.manifest.v2+json"
for FILE in $(find v2 -type f)
do
  echo "/$FILE"
  echo "  Docker-Content-Digest: $(sha256sum $FILE | awk '{print $1}')"
done
) > _headers

