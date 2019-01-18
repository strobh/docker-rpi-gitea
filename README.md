# Gitea Docker Image for Raspberry Pi on ARMv7

This repository containes a Dockerfile to create an image of [Gitea](https://gitea.io) for Raspberry Pi on ARMv7.
The image is based on the official Gitea ARMv7 build and is automatically updated by my Raspberry Pi and pushed to Docker Hub ([strobi/rpi-gitea](https://cloud.docker.com/u/strobi/repository/docker/strobi/rpi-gitea)).


## Build the image

To build the image using `docker` run:

```bash
# BUILD_VERSION determines which version of gitea is used for the image
# BUILD_VERSION must be the tag name of the release on GitHub without `v`, e.g. `1.6.0`
BUILD_VERSION=$(curl -s https://api.github.com/repos/go-gitea/gitea/releases/latest | jq -r .tag_name )
BUILD_VERSION=${BUILD_VERSION:1}

# Build
docker build --no-cache --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') --build-arg BUILD_VERSION=${LATEST_RELEASE} .
```


## Start the container

To start the container using `docker` run:

```bash
docker run -d -p 2200:22 -p 3000:3000 -v ~/gitea:/data strobi/rpi-gitea:latest
```

If you want to use `docker-compose` to manage the container, create a file named `docker-compose.yml` with the following content: 

```
version: '2'

networks:
  gitea:
    external: false

services:
  gitea:
    image: strobi/rpi-gitea:latest
    restart: unless-stopped
    networks:
      - gitea
    volumes:
      - /home/pi/gitea:/data
    ports:
      - "3000:3000"
      - "2200:22"
    environment:
      - USER_UID=1000
      - USER_GID=1000
```
