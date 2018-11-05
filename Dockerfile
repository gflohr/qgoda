FROM perl:5.26
MAINTAINER Qgoda (https://github.com/gflohr/qgoda/issues)

RUN apt-get update && apt-get install -y make git curl apt-transport-https gnupg dumb-init
# We need a recent nodejs.
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn

COPY . /root/qgoda/

WORKDIR /root/qgoda/

RUN cpanm .

VOLUME /data
WORKDIR /data

ENTRYPOINT ["/usr/bin/dumb-init", "--", "qgoda"]
