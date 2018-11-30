FROM ubuntu:bionic
MAINTAINER Qgoda (https://github.com/gflohr/qgoda/issues)

RUN apt-get update && apt-get install -y make \
    gcc \
    git \
    curl \
    apt-transport-https \
    gnupg \
    dumb-init \
    cpanminus \
    libmoo-perl \
    libanyevent-perl \
    libwww-perl \
    libtemplate-perl \
    libyaml-perl \
    libfile-copy-recursive-perl \
    libipc-signal-perl \
    libcpanel-json-xs-perl \
    libinline-perl \
    libdata-walk-perl \
    libfile-homedir-perl \
    libarchive-extract-perl \
    libgit-repository-perl \
    libtext-markdown-perl \
    libio-interactive-perl \
    libjson-perl \
    libboolean-perl \
    libtext-unidecode-perl \
    libtest-deep-perl \
    libmoox-late-perl \
    libcapture-tiny-perl \
    libtest-without-module-perl \
    libpath-iterator-rule-perl \
    libtext-glob-perl \
    libnumber-compare-perl \
    libtest-filename-perl \
    libmoox-types-mooselike-perl \
    libtest-fatal-perl \
    liblinux-inotify2-perl \
    libtest-exception-perl \
    libsub-uplevel-perl \
    libtest-requires-perl \
    liblocale-po-perl \
    libtest-output-perl \
    libtext-trim-perl

# We need a recent nodejs.
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn

COPY . /root/qgoda/

WORKDIR /root/qgoda/

RUN cpanm .

RUN rm -rf /root/imperia /root/.cpanm

VOLUME /var/www/qgoda

RUN groupadd qgoda && useradd -r -g qgoda qgoda
RUN chown -R qgoda:qgoda /var/www/qgoda

WORKDIR /var/www/qgoda

ENTRYPOINT ["/usr/bin/dumb-init", "--", "qgoda"]
