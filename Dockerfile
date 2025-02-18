FROM alpine:latest AS builder
LABEL org.opencontainers.image.authors="guido.flohr@cantanea.com"

RUN apk add \
	binutils \
	curl \
	gcc \
	git \
	make \
	musl-dev \
	nodejs \
	npm \
	perl \
	perl-anyevent \
	perl-app-cpanminus \
	perl-boolean \
	perl-cpanel-json-xs \
	perl-data-dump \
	perl-dev \
	perl-file-copy-recursive \
	perl-file-homedir \
	perl-html-tree \
	perl-inline \
	perl-locale-codes \
	perl-json \
	perl-libwww \
	perl-linux-inotify2 \
	perl-lwp-protocol-https \
	perl-module-build \
	perl-path-iterator-rule \
	perl-path-tiny \
	perl-template-toolkit \
	perl-test-exception \
	perl-test-memory-cycle \
	perl-test-output \
	perl-test-without-module \
	perl-text-unidecode \
	perl-timedate \
	perl-yaml \
	perl-yaml-xs \
	&& \
	npm install -g yarn

WORKDIR /root

# Install a specific JavaScript::Duktape::XS version
RUN git clone https://github.com/gonzus/JavaScript-Duktape-XS && \
	cd JavaScript-Duktape-XS && \
	cpanm --notest . && \
	cd .. && rm -rf JavaScript-Duktape-XS

# Copy source code and install dependencies
COPY . /root/qgoda/
WORKDIR /root/qgoda/
RUN cpanm --notest . && rm -rf /root/qgoda /root/.cpanm

FROM alpine:latest AS runtime

ARG WITH_NODE

RUN apk add --no-cache perl dumb-init && \
	test -n "$WITH_NODE" && \
	apk add --no-cache nodejs npm

# Create a non-root user
RUN addgroup -S qgoda && adduser -S qgoda -G qgoda

# Set working directory for bind mount
WORKDIR /data

# Copy necessary files from the builder stage
COPY --from=builder /usr/local/bin/qgoda /usr/local/bin/qgoda
COPY --from=builder /usr/lib/perl5 /usr/lib/perl5
COPY --from=builder /usr/share/perl5 /usr/share/perl5
COPY --from=builder /usr/local/lib/perl5 /usr/local/lib/perl5
COPY --from=builder /usr/local/share/perl5 /usr/local/share/perl5

# Run as non-root user
USER qgoda

ENTRYPOINT ["/usr/bin/dumb-init", "--", "qgoda"]

