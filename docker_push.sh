#!/bin/bash

set -e

# shellcheck disable=SC2153
docker_organization=$DOCKER_ORGANIZATION

if [ -z "$DOCKER_REGISTRY" ]; then
  if [ -z "$docker_organization" ]; then
    echo "::error::No DOCKER_ORGANIZATION set. This is mandatory when using docker.io"
    exit 1
  fi
  DOCKER_REGISTRY="docker.io"
  docker_registry_prefix="$DOCKER_REGISTRY/$docker_organization"
  echo "Docker organization: $docker_organization"
else
  docker_registry_prefix="$DOCKER_REGISTRY"
fi

echo "docker_registry_prefix: $docker_registry_prefix"

if [ "$#" -lt 4 ]; then
  echo "::error::You need to provide a directory with a Dockerfile in it, Docker image name, base-dir and a tag."
  exit 1
fi

builddir=$1
shift
imagename=$1
shift
# basedir=$1 // Is not used, so why bother to capture this in a variable.
shift
alltags=$*
IFS=' '
read -ra tags <<<"$alltags"
basetag=${tags[0]}

if [ -z "$DOCKER_PASSWORD" ]; then
  echo "::error::No DOCKER_PASSWORD set. Please provide"
  exit 1
fi

if [ -z "$DOCKER_USERNAME" ]; then
  echo "::error::No DOCKER_USERNAME set. Please provide"
  exit 1
fi

echo "Login to docker"
echo "--------------------------------------------------------------------------------------------"
echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin

{
  echo '## Images pushed'
  echo ''
  echo '| Image |'
  echo '| ---- |'
  echo "| $docker_registry_prefix/$imagename:$basetag |"
} >> "$GITHUB_STEP_SUMMARY"

docker push "$docker_registry_prefix"/"$imagename":"$basetag"

for tag in "${tags[@]:1}"; do
  echo "| $docker_registry_prefix/$imagename:$tag |" >> "$GITHUB_STEP_SUMMARY"
  docker push "$docker_registry_prefix"/"$imagename":"$tag"
done
echo '' >> "$GITHUB_STEP_SUMMARY"

echo "--------------------------------------------------------------------------------------------"

echo "Update readme"
echo "--------------------------------------------------------------------------------------------"

export DOCKER_REPOSITORY="$docker_organization"/"$imagename"

[ "$DOCKER_REGISTRY" = "docker.io" ] && "${FOREST_DIR}"/update_readme.sh || echo "no docker.io so no update"

echo "============================================================================================"
echo "Finished pushing docker images: $builddir"
echo "============================================================================================"
