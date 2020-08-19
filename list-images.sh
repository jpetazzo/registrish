#!/bin/sh
find v2 -path */manifests/* \
  | cut -d/ -f2- \
  | sed s,/manifests/,:,

