FROM ubuntu:jammy
LABEL org.opencontainers.image.authors="guido.flohr@cantanea.com"

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 \
    DEBIAN_FRONTEND=noninteractive \
    NODE_VERSION=18

RUN apt-get update && apt-get install -y --no-install-recommends \
    make gcc curl apt-transport-https gnupg dumb-init cpanminus \
    build-essential libc-dev \
    git \
    libmoo-perl libanyevent-perl libwww-perl libtemplate-perl libyaml-perl \
    libfile-copy-recursive-perl libipc-signal-perl libcpanel-json-xs-perl \
    libinline-perl libdata-walk-perl libfile-homedir-perl libarchive-extract-perl \
    libgit-repository-perl libtext-markdown-perl libio-interactive-perl \
    libjson-perl libboolean-perl libtext-unidecode-perl libtest-deep-perl \
    libmoox-late-perl libcapture-tiny-perl libtest-without-module-perl \
    libpath-iterator-rule-perl libtext-glob-perl libnumber-compare-perl \
    libtest-filename-perl libmoox-types-mooselike-perl libtest-fatal-perl \
    liblinux-inotify2-perl libtest-exception-perl libsub-uplevel-perl \
    libtest-requires-perl liblocale-po-perl libtest-output-perl libtext-trim-perl && \
    curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    npm install -g yarn

WORKDIR /root

# Not yet on CPAN.
RUN cpanm https://github.com/gflohr/AnyEvent-Filesys-Watcher/releases/download/v0.1.0/AnyEvent-Filesys-Watcher-v0.1.0.tar.gz

# Install a specific JavaScript::Duktape::XS version
RUN git clone https://github.com/gonzus/JavaScript-Duktape-XS && \
	cd JavaScript-Duktape-XS && \
	cpanm . && \
	cd .. && rm -rf JavaScript-Duktape-XS

# Copy source code and install dependencies
COPY . /root/qgoda/
WORKDIR /root/qgoda/
RUN cpanm . && rm -rf /root/qgoda /root/.cpanm

# Create a non-root user
RUN groupadd -r qgoda && useradd -r -g qgoda qgoda

# Set working directory for bind mount
WORKDIR /data

# Run as non-root user
USER qgoda

ENTRYPOINT ["/usr/bin/dumb-init", "--", "qgoda"]

