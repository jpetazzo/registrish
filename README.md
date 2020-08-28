# Registrish

This is *kind of* a Docker registry, but with many restrictions:

- it's read-only (you can `pull` but you cannot `push`)
- it only supports public access (no authentication)
- it only supports Image Manifest Version 2, Schema 2
- it probably doesn't support multi-arch images

However, it can be deployed without running the registry code, using
almost any static file hosting service. For instance:

- a plain NGINX server (without LUA, JSX, or whatever custom module)
- the [Netlify] CDN
- an object store like S3, or a compatible one like [Scaleway]


## Example

The following commands will run an Alpine image hosted on various
locations, thanks to registrish.

Netlify:
```bash
docker run registrish.netlify.app/alpine echo hello there
```

S3:
```bash
docker run registrish.s3.amazonaws.com/alpine echo hello there
```

Scaleway object store:
```bash
docker run registrish.s3.fr-par.scw.cloud/alpine echo hello there
```


## How to use this

Quick example. You need to have either a local Docker Engine,
or [Skopeo] installed, to pull images.

```bash
# First, fetch an image (or a few).
# If you have a Docker Engine running locally:
./fetch-image-from-docker-hub-with-intermediate-registry.sh alpine latest
# Or, if you have Skopeo:
./fetch-image-from-docker-hub-with-skopeo.sh alpine latest

# Check that image was correctly downloaded.
./list-images.sh

# Start NGINX in a local Docker container. (It will be on port 5555.)
docker-compose up -d
# Run image from the registry.
docker run localhost:5555/alpine echo hello there

# Deploy to Netlify.
# (This assumes that you have installed and configured the Netlify CLI.)
netlify deploy
# Run image from the registry.
docker run deployed-site-name.netlify.app/alpine echo hello there

# Deploy to an S3 bucket.
# (This assumes that your AWS credentials have been set up correctly,
# e.g. through AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY variables.)
BUCKETNAME=bucketname
aws s3 sync --acl public-read v2/ s3://$BUCKETNAME/v2/
aws s3 cp   --acl public-read v2/ s3://$BUCKETNAME/v2/  \
    --recursive --exclude '*' --include '*/manifests/*' \
    --content-type application/vnd.docker.distribution.manifest.v2+json  \
    --metadata-directive REPLACE
# Run image from the registry.
docker run $BUCKETNAME.s3.amazonaws.com/alpine echo hello there

# Deploy to an S3-compatible object store, e.g. Scaleway.
# (This assumes that your credentials have been set up correctly.)
BUCKETNAME=bucketname
ENDPOINT=s3.fr-par.scw.cloud
aws s3 sync --acl public-read v2/ s3://$BUCKETNAME/v2/  \
    --endpoint-url https://$ENDPOINT
aws s3 cp   --acl public-read v2/ s3://$BUCKETNAME/v2/  \
    --recursive --exclude '*' --include '*/manifests/*' \
    --content-type application/vnd.docker.distribution.manifest.v2+json  \
    --metadata-directive REPLACE \
    --endpoint-url https://$ENDPOINT
# Run image from the registry.
docker run $BUCKETNAME.$ENDPOINT/alpine echo hello there
```


## How it works

The Docker Registry is *almost* a static web server.
When the Docker Engine pulls an image, it will download
`/v2/<imagename>/manifests/<tag>`, for instance
`/v2/busybox/manifests/latest`. This is a JSON file
that contains references to a number of *blobs*.
One of these blobs will be a JSON file containing
the configuration of the image (entry point, command,
volumes, etc.) and the other ones will be the layers
of the images. The blobs are stored in
`/v2/<imagename>/blobs/sha256:<sha-of-the-blob>`.

There is one tiny twist: when serving the image manifest,
the `Content-Type` HTTP header should be
`application/vnd.docker.distribution.manifest.v2+json`.
Otherwise, the Docker Engine will interpret the manifest
as a different format, will fail to verify its signature,
and will give you the error `missing signature key`.


## `Docker-Content-Digest`

A while ago (at some point in 2018, maybe?) I tried to
implement this but didn't succeed. I don't know exactly
what happened, but I had the impression that the
`Docker-Content-Digest` header was mandatory. So when
I tried again in August 2020, the first thing I did was
to generate `Docker-Content-Digest` headers for both
manifests and blobs. This is the job of the scripts
`generate-netlify-headers.sh` and `generate-nginx-config.sh`.
It looks like this is, in fact, not necessary.
I've kept these scripts here just in case.
(I tried to pull from registrish, without Docker-Content-Digest
headers, using an old version of the Docker Engine - 18.03 -
and it worked anyway, so I don't know what I got wrong
back then?)

*It might be the case that when using an older version of the
manifest format, that header becomes mandatory.*


## Notes

As mentioned above, this probably doesn't work with
multiarch images. It may or may not be easy to adapt.

Netlify is very fast to serve web pages, but not so much
to serve binary blobs. (I suspect that they throttle them
on purpose to prevent abuse, but that's just an intuition.)

Their [terms of service] state the following (in August 2020):

> Users must exercise caution when hosting large downloads (>10MB).
> Netlify reserves the right to refuse to host any large downloadable files.


## Providers and object stores that might not work

I've tried to use [OVHcloud] object storage, but it
doesn't seem to be easy to do so. OVHcloud storage buckets
have very long URLs like
https://storage.gra.cloud.ovh.net/v1/AUTH_xxx-long-tenant-id-xxx/bucketname
and the Docker registry protocol doesn't support uppercase
characters in image names.

It's possible to use custom domain names, but then there
are certificate issues. If you know an easy way to make
it work, let me know!


## Similar work and prior art

- [NicolasT/static-container-registry](https://github.com/NicolasT/static-container-registry)
- [singularityhub/registry](https://github.com/singularityhub/registry)


[Netlify]: http://netlify.com/
[OVHcloud]: https://www.ovhcloud.com/en/public-cloud/prices/#storage
[Scaleway]: https://www.scaleway.com/en/pricing/#object-storage
[Skopeo]: https://github.com/containers/skopeo
[terms of service]: https://www.netlify.com/tos/
