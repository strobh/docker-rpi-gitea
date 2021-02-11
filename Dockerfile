FROM alpine:3.13
LABEL maintainer="developer@tobias-heckel.de"

# Build arguments need to be passed to `docker build` with `--build-arg KEY=VALUE`

# BUILD_DATE is the datetime the image was build and is used in a label
# BUILD_DATE should be formatted according to RFC 3339:
# BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
ARG BUILD_DATE

# BUILD_VERSION determines which version of gitea is used for the image
# BUILD_VERSION must be the tag name of the release on GitHub without `v`, e.g. `1.6.0`
# BUILD_VERSION=$(curl -s https://api.github.com/repos/go-gitea/gitea/releases/latest | jq -r .tag_name )
# BUILD_VERSION=${BUILD_VERSION:1}
ARG BUILD_VERSION

# Labels
# Label Schema 1.0.0-rc.1 (http://label-schema.org/rc1/)
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=$BUILD_DATE
LABEL org.label-schema.version=$BUILD_VERSION
LABEL org.label-schema.name="strobi/rpi-gitea"
LABEL org.label-schema.description="Gitea for Raspberry Pi on ARMv7"
LABEL org.label-schema.url="https://gitea.io"
LABEL org.label-schema.vcs-url="https://github.com/go-gitea/gitea"
LABEL org.label-schema.docker.cmd="docker run -d -p 2200:22 -p 3000:3000 -v ~/gitea:/data strobi/rpi-gitea"

# Ports that are listened on in the container
# Can be matched to other ports on the host via `docker run`
EXPOSE 22 3000

# Directory in the container that is mounted from the host
VOLUME /data

# Checks whether gitea is listening on port 3000
# Enables docker to automatically restart container if it is not healthy
HEALTHCHECK --interval=1m --timeout=10s \
    CMD nc -z localhost 3000 || exit 1

# Default environment variables for gitea
ENV USER=git
ENV GITEA_CUSTOM=/data/git

# Create gitea group and user
# UID and GID in container must match those of user on host (usually pi: 1000)
RUN addgroup \
        -S \
        -g 1000 \
        git \
    && adduser \
        -S -D -H \
        -u 1000 \
        -h /data/git \
        -G git \
        -s /bin/bash \
        -g "" \
        git \
    && echo "git:$(dd if=/dev/urandom bs=24 count=1 status=none | base64)" | chpasswd

# Install build dependencies (will be deleted from the image after the build)
RUN apk --no-cache --virtual .build-deps add \
    rsync

# Install dependencies
RUN apk --no-cache add \
    bash \
    ca-certificates \
    curl \
    gettext \
    git \
    linux-pam \
    openssh \
    s6 \
    sqlite \
    su-exec \
    gnupg \
    tzdata

# Pull docker files (sparse checkout: https://stackoverflow.com/a/13738951),
# merge them into /etc and /usr/bin/ with `rsync` and delete repository again
RUN mkdir /gitea-docker \
    && cd /gitea-docker \
    && git init \
    && git remote add -f origin https://github.com/go-gitea/gitea.git \
    && git config core.sparseCheckout true \
    && echo "docker/" >> .git/info/sparse-checkout \
    && git pull origin master \
    && rsync -av /gitea-docker/docker/root/ / \
    && rm -rf /gitea-docker

# Get gitea and verify signature
RUN mkdir -p /app/gitea \
    && gpg --keyserver keyserver.ubuntu.com --recv 7C9E68152594688862D62AF62D9AE806EC1592E2 \
    && curl -sLo /app/gitea/gitea https://github.com/go-gitea/gitea/releases/download/v${BUILD_VERSION}/gitea-${BUILD_VERSION}-linux-arm-6 \
    && curl -sLo /app/gitea/gitea.asc https://github.com/go-gitea/gitea/releases/download/v${BUILD_VERSION}/gitea-${BUILD_VERSION}-linux-arm-6.asc \
    && gpg --verify /app/gitea/gitea.asc /app/gitea/gitea \
    && chmod 0755 /app/gitea/gitea \
    && ln -s /app/gitea/gitea /usr/local/bin/gitea \
    && rm -rf /root/.gnupg

# Delete build dependencies
RUN apk del .build-deps

# Entrypoint
ENTRYPOINT ["/usr/bin/entrypoint"]
CMD ["/bin/s6-svscan", "/etc/s6"]
