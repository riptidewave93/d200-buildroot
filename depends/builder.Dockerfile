# Builder image: makes the build repeatable on any host
FROM debian:trixie-slim

RUN set -e; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        build-essential git ca-certificates wget cpio file unzip rsync bc \
        libncurses-dev python3 perl patch diffutils findutils \
        bzip2 gzip xz-utils tar sed gawk locales; \
    sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen; locale-gen; \
    apt-get clean; rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
