FROM --platform=$BUILDPLATFORM ruby:3.3.5-alpine3.20 AS builder

RUN apk add --no-cache build-base make cmake gcc npm

RUN npm install -g wavedrom-cli

RUN gem update bundler
RUN gem install bundler jekyll

COPY Gemfile /tmp/Gemfile
RUN cd /tmp && \
    bundle install && \
    bundle update

