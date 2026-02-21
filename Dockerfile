ARG BUILDER_TAG=latest

FROM --platform=$BUILDPLATFORM git.pfarley.dev/pfarley/blog-builder:${BUILDER_TAG} AS builder

COPY . /opt/build
RUN set -ex; \
    cd /opt/build/blog; \
    bundle exec jekyll build; \
    cd /opt/build/www; \
    bundle exec jekyll build

FROM nginx:1.27.2-alpine3.20-slim AS server

RUN mkdir /usr/share/nginx/html/www; \
    mkdir /usr/share/nginx/html/blog

COPY --from=builder /opt/build/www/_site/ /usr/share/nginx/html/www
COPY --from=builder /opt/build/blog/_site/ /usr/share/nginx/html/blog

COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./nginx-common.conf /etc/nginx/nginx-common.conf
COPY ./robots.txt /usr/share/nginx/html/

EXPOSE 80

