#!/bin/bash
set -euo pipefail

build_tag=$1
name=player
node=$2
org=$3
export sunbird_content_editor_artifact_url=$4
export sunbird_collection_editor_artifact_url=$5
export sunbird_generic_editor_artifact_url=$6
commit_hash=$(git rev-parse --short HEAD)

rm -rf src/app/app_dist/
rm -rf src/app/player-dist.tar.gz
cd src/app
# Running build inside docker
echo "entering to node container"
# Creating a docker volume for all the npm lib caching
# if you want to clear the cache simply delete the volume
# `docker volume rm node12`
# Running the docker command with less priority as build takes time, don't want to choke other processes.
cat<< EOF > buildscript.sh
whoami
node -v
npm -v
npm set progress=false
nice npm install  --unsafe-perm
nice npm run deploy
cd app_dist
nice npm install --production  --unsafe-perm
sed -i "/version/a\  \"buildHash\": \"${commit_hash}\"," package.json
EOF

docker run --rm -v /tmp/buildscript.sh:/tmp/buildscript.sh -v node12_npm_cache:/var/lib/jenkins/.npm/ -v /etc/passwd:/etc/passwd -u `id -u`:`id -g` -v `pwd`:`pwd` -v$(pwd):/var/lib/jenkins/player -w /var/lib/jenkins/player circleci/node:12 /bin/bash buildscript.sh

cd ../..

docker build --no-cache --label commitHash=$(git rev-parse --short HEAD) -t ${org}/${name}:${build_tag} .

echo {\"image_name\" : \"${name}\", \"image_tag\" : \"${build_tag}\",\"commit_hash\" : \"${commit_hash}\", \"node_name\" : \"$node\"} > metadata.json
