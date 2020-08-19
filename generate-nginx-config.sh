#!/bin/sh
set -ue

(
cat <<EOF
server {
  listen 5000;
  root /registry;
  location ~ /.*/manifests/.* {
    error_page 404 /error.json;
    default_type application/vnd.docker.distribution.manifest.v2+json;
  }
EOF
for FILE in $(find v2 -type f)
do
  echo "  location = /$FILE {"
  echo "   add_header Docker-Content-Digest $(sha256sum $FILE | awk '{print $1}');"
  case "$FILE" in */manifests/*)
  echo "   default_type application/vnd.docker.distribution.manifest.v2+json;" ;;
  esac
  echo "  }"
done
echo "}"
) > registry.conf
