FROM ubuntu:bionic
MAINTAINER Qgoda (https://github.com/gflohr/qgoda/issues)

ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

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
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && \
	apt-get install -y nodejs && \
	curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
	echo "deb https://dl.yarnpkg.com/debian/ stable main" \
		> /etc/apt/sources.list.d/yarn.list && \
	apt-get update && apt-get install -y yarn

# Newer versions of JavaScript::Duktape::XS do not work.
WORKDIR /root
RUN curl -Ss https://cpan.metacpan.org/authors/id/G/GO/GONZUS/JavaScript-Duktape-XS-0.000074.tar.gz \
		>JavaScript-Duktape-XS-0.000074.tar.gz && \
	tar xzf JavaScript-Duktape-XS-0.000074.tar.gz && \
	cd JavaScript-Duktape-XS-0.000074 && \
	cpanm . && \
	rm -r /root/JavaScript-Duktape-XS-0.000074

COPY . /root/qgoda/

WORKDIR /root/qgoda/

RUN cpanm . --notest && rm -rf /root/qgoda /root/.cpanm

VOLUME /data

RUN groupadd qgoda && useradd -r -g qgoda qgoda && chown -R qgoda:qgoda /data

WORKDIR /data

ENTRYPOINT ["/usr/bin/dumb-init", "--", "qgoda"]
