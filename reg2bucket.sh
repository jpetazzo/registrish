#!/bin/sh

set -e

[ "$BUCKET" ] || {
  echo "Please set the BUCKET environment variable."
  exit 1
}

# We don't really need to list the bucket, but this
# will bail early if we lack access to the bucket.
aws s3 $ENDPOINT ls s3://$BUCKET

aws s3 $ENDPOINT sync v2/ s3://$BUCKET/v2/ \
  --acl public-read \
  --exclude '*/manifests/*'

for MANIFEST in $(find v2 -path '*/manifests/*'); do
  CONTENT_TYPE=$(jq -r .mediaType < $MANIFEST)
  if [ "$CONTENT_TYPE" = "null" ]; then
    CONTENT_TYPE="application/vnd.docker.distribution.manifest.v1+prettyjws"
  fi
  aws s3 $ENDPOINT cp $MANIFEST s3://$BUCKET/$MANIFEST \
    --acl public-read \
    --content-type $CONTENT_TYPE  \
    --metadata-directive REPLACE
done
