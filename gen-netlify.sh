#!/bin/sh
set -ue

(
for FILE in $(find v2 -type f); do
  echo "/$FILE"
  echo "  Docker-Content-Digest: sha256:$(sha256sum $FILE | awk '{print $1}')"
  case "$FILE" in */manifests/*)
    CONTENT_TYPE=$(jq -r .mediaType < $FILE)
    if [ "$CONTENT_TYPE" = null ]; then
      CONTENT_TYPE="application/vnd.docker.distribution.manifest.v1+prettyjws"
    fi
    echo "  Content-Type: $CONTENT_TYPE"
    ;;
  esac
done
) > _headers

