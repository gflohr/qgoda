FROM perl:5.26

RUN apt-get update && apt-get install -y make git apt-transport-https
# We need a recent nodejs.
RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
RUN apt-get install -y nodejs
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -
RUN echo "deb https://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list
RUN apt-get update && apt-get install -y yarn

COPY . /root/qgoda/

WORKDIR /root/qgoda/

RUN cpanm --installdeps .
RUN cpanm -n .

VOLUME /data
WORKDIR /data

ENTRYPOINT ["qgoda"]
