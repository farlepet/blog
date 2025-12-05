ARG BUILDER_TAG=latest

FROM --platform=$BUILDPLATFORM git.pfarley.dev/pfarley/blog-builder:${BUILDER_TAG} AS builder

COPY . /opt/build
RUN set -ex; \
    cd /opt/build; \
    bundle exec jekyll build

FROM nginx:1.27.2-alpine3.20-slim AS server

COPY --from=builder /opt/build/_site/ /usr/share/nginx/html
COPY ./nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

