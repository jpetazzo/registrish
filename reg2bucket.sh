#!/bin/sh

set -e

[ "$BUCKET" ] || {
  echo "Please set the BUCKET environment variable."
  exit 1
}

# We don't really need to list the bucket, but this
# will bail early if we lack access to the bucket.
aws s3 $ENDPOINT ls s3://$BUCKET

aws s3 $ENDPOINT cp v2/ s3://$BUCKET/v2/ \
  --acl public-read \
  --recursive --exclude '*/manifests/*'

for MANIFEST in $(find v2 -path '*/manifests/*'); do
  CONTENT_TYPE=$(jq -r .mediaType < $MANIFEST)
  aws s3 $ENDPOINT cp $MANIFEST s3://$BUCKET/$MANIFEST \
    --acl public-read \
    --content-type $CONTENT_TYPE  \
    --metadata-directive REPLACE
done