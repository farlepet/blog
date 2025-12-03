FROM --platform=$BUILDPLATFORM ruby:3.3.5-alpine3.20 AS builder

RUN apk add --no-cache build-base make cmake gcc npm

RUN npm install -g wavedrom-cli

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



FROM nginx:1.27.2-alpine3.20-slim AS server

COPY --from=builder /opt/build/_site/ /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

