# Registrish

This is *kind of* a Docker registry, but with many restrictions:

- it's read-only (you can `pull` but you cannot `push`)
- it only supports public access (no authentication)
- it only supports a subset of the Docker Distribution API

The last point means that pulls from registrish will hopefully work,
but might break in unexpected ways. See [Limitations] below for more info.

On the bright side, registrish can be deployed without running
the registry code, using almost any static file hosting service.
For instance:

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


## Hosting your images with registrish

In the following example, we are going to host the official image
`alpine:latest` with registrish.

Let's set a couple of env vars for convenience:

```bash
export DIR=tmp IMAGE=alpine TAG=latest
```

Let's obtain the manifests and blobs of the image. This requires [Skopeo].

```bash
skopeo copy --all docker://$IMAGE:$TAG dir:$DIR
```

The `--all` flag means that we want to obtain a *manifest list*
(i.e a multi-arch image), if one is available.

Then, we're going to move the files downloaded by Skopeo to their
respective directories. Blobs go to the `blobs` directory, and manifests
go to the `manifests` directory. All files get renamed to `sha256:xxx`
where `xxx` is their SHA256 checksum. The top-level manifest also gets
copied to the tag name to allow pulling by tag.

```bash
./dir2reg.sh
```

You can check that everything looks fine with the `tree` command:

```bash
tree v2
```

There should be:

- a bunch of `sha256:xxx` files in `blobs`,
- a bunch of `sha256:xxx` files in `manifests`,
- one tag file (e.g. `latest`) in `manifests`.

Then, pick a registrish back-end and follow its specific instructions.


### NGINX server

Generate the NGINX configration file. The configuration file will
set `content-type` HTTP headers.

```bash
./gen-nginx.sh
```

Start NGINX in a local Docker container. It will be on port 5555.

```bash
docker-compose up
```

The image will be available as `localhost:5555/$IMAGE:$TAG`.


### Netlify

Generate the Netlify headers file.

```bash
./gen-netlify.sh
```

To deploy to Netlify, it's better to deploy only the `v2` directory and the `_headers` file:

```bash
TEMP=$(mktemp -d)
cp -a v2 _headers $TEMP
npx netlify deploy --dir $TEMP --prod
```


### S3 bucket or compatible

The following assumes that you have configured your S3 credentials,
for instance by setting `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
environment variables.

Update this variable with your bucket name.
```bash
export BUCKET=registrish
```

If you are using an S3-compatible API (e.g. Scaleway), set the
following variables (or set the corresponding parameters in your
profile).

```bash
export AWS_DEFAULT_REGION=fr-par
export ENDPOINT="--endpoint-url https://s3.fr-par.scw.cloud"
```

Sync files to the bucket.

```bash
./reg2bucket.sh
```

The image will be available as `$BUCKET.s3.amazonaws.com/$IMAGE:$TAG`
(for S3) or `$BUCKETNAME.$ENDPOINT/$IMAGE:$TAG` (for compatible APIs).


## Testing

When testing registrish, we want to be sure that the entire image
will be pulled correctly with all its layers. If we try on our local
container engine, we might already have some manifests and layers.

One way to test that is to use a throwaway Docker-in-Docker container.

```bash
docker run --name dind -d --privileged --net host docker:dind
docker exec dind docker pull REGISTRISH-IMAGE
docker rm -f dind
```


## How it works

The Docker Registry is *almost* a static web server.
The main trick is to handle `Content-Type` headers correctly.

As far as I understand, this is what happens when a container engine
tries to pull an image by tag.

- First, the engine wants to know the hash of the manifest that we're
  trying to pull.
- To learn that hash, the engine makes a `HEAD` request on
  `/v2/<image>/manifests/<tag>`.
  - If the registry sends a `Docker-Content-Digest` header (which will
    look like `sha256:<xxx>`), that header is the hash, so the engine
    can go to the next step.
  - If the registry doesn't send a `Docker-Content-Digest` header,
    the engine makes a `GET` request on `/v2/<image>/manifests/<tag>`,
    computes the SHA256 checksum of the response body (let's say it's
    `<xxx>` to match the previous example). Now the engine has the hash
    (at the cost of an extra HTTP request).
- The engine makes a request to `/v2/<image>/manifests/sha256:<xxx>`.
  The `Content-Type` will indicate if we're dealing with a v2 manifest
  (single-arch image) or a v2 manifest list (multi-arch image).
  - If it's a v2 manifest, we can use it directly.
  - If it's a manifest list, it contains a list of manifests. Each entry
    has a platform (e.g. `linux/amd64`) and a hash (for instance `sha256:<yyy>`).
    The engine picks the entry that it deems appropriate (because it
    matches its architecture, or one that it's compatible with) and it
    requests the corresponding manifest, on `/v2/<image>/manifests/sha256:<yyy>`.
    *That* manifest should be a v2 manifest.
- The engine now has a v2 manifest. In the v2 manifest, there is a list
  of *blobs*. One of these blobs will be a JSON file containing
  the configuration of the image (entry point, command,
  volumes, etc.) and the other ones will be the layers
  of the images. The blobs are stored in
  `/v2/<image>/blobs/sha256:<sha-of-the-blob>`.

As long as we use the correct `Content-Type` when serving image manifests,
the container engine should be happy. *Unless...*

*Unless* the container engine explicitly asks a specific type of
manifests, which it can do by using `Accept` request headers.
If the engine asks for a v2 manifest (single-arch) and we serve
a v2 manifest list (multi-arch), I expect that it will complain loudly.

I don't understand why my former colleagues at Docker decided
to go with this scheme, instead of e.g. keeping v2 manifests in `/manifests`
and storing the multi-arch manifest lists in e.g. `/lists`.
It would have avoided using HTTP headers to alter the content served
by the registry. 🤷🏻

I also don't understand the point of that `HEAD` request and custom
`Docker-Content-Digest` HTTP header. The same result could have been
achieved with an explicit HTTP route to resolve tags to hashes. 🤷🏻


## Notes

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


## TODO

- add 404 page on Netlify
- try CloudFlare R2 as soon as it's out :)


## Similar work and prior art

- [NicolasT/static-container-registry](https://github.com/NicolasT/static-container-registry)
- [singularityhub/registry](https://github.com/singularityhub/registry)


[Limitations]: #limitations
[Netlify]: http://netlify.com/
[OVHcloud]: https://www.ovhcloud.com/en/public-cloud/prices/#storage
[Scaleway]: https://www.scaleway.com/en/pricing/#object-storage
[Skopeo]: https://github.com/containers/skopeo
[terms of service]: https://www.netlify.com/tos/
