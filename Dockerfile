FROM --platform=$BUILDPLATFORM ruby:3.3-alpine3.19 AS builder

RUN apk add --no-cache build-base make cmake gcc

RUN gem update bundler
RUN gem install bundler jekyll

# This prevents us from needing to install everything every time we update a file
COPY Gemfile /tmp/Gemfile
RUN cd /tmp; bundle install

COPY . /opt/build
RUN set -ex; \
    cd /opt/build; \
    bundle install; \
    bundle update; \
    bundle exec jekyll build



FROM --platform=$TARGETPLATFORM nginx:1.25.4-alpine3.18-slim AS server

COPY --from=builder /opt/build/_site/ /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
EXPOSE 443

