#!/bin/sh
set -ue

cp error.json v2/
echo "ErrorDocument 404 /v2/error.json" >"v2/.htaccess"

for MANIFEST_DIR in v2/*/manifests; do
  (
    # Set content type
    for FILE in $(find "$MANIFEST_DIR" -type f -not -name .htaccess); do
      CONTENT_TYPE=$(jq -r .mediaType "$FILE")
      if [ "$CONTENT_TYPE" = "null" ]; then
        CONTENT_TYPE="application/vnd.docker.distribution.manifest.v1+prettyjws"
      fi
      echo "<Files $(basename "$FILE")>"
      echo "  ForceType $CONTENT_TYPE"
      echo "</Files>"
    done

    # Add Docker-Content-Digest header to tags
    for FILE in $(find "$MANIFEST_DIR" -type f -not -name .htaccess -not -name 'sha256*'); do
      sha256=$(sha256sum "$FILE" | cut -d ' ' -f1)
      echo "<Files $(basename "$FILE")>"
      echo "  Header add Docker-Content-Digest sha256:$sha256"
      echo "</Files>"
    done
  )>"$MANIFEST_DIR/.htaccess"
done
