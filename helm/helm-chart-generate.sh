#!/usr/bin/env bash
# Author: bphd
# License: GPLv3+
# Repo: https://github.com/bphd/PodMan-OSX/
# cd ../helm

rm -f PodMan-osx-*.tgz
helm package .
helm repo index . --url https://bphd.github.io/PodMan-OSX/helm/
