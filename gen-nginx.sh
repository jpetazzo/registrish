#!/bin/sh
set -ue

(
cat <<EOF
server {
  listen 5000;
  root /registry;
  location ~ /.*/manifests/.* {
    error_page 404 /error.json;
  }
EOF
for FILE in $(find v2 -type f)
do
  echo "  location = /$FILE {"
  echo "   add_header Docker-Content-Digest sha256:$(sha256sum $FILE | awk '{print $1}');"
  case "$FILE" in */manifests/*)
    CONTENT_TYPE=$(jq -r .mediaType < $FILE)
    if [ "$CONTENT_TYPE" = "null" ]; then
      CONTENT_TYPE="application/vnd.docker.distribution.manifest.v1+prettyjws"
    fi
    echo "   default_type $CONTENT_TYPE;"
    ;;
  esac
  echo "  }"
done
echo "}"
) > registry.conf
