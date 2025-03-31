#!/bin/sh

docker run -d --name "blog" \
	  -p 80:80 -p 443:443 -p 443:443/udp \
	  --restart unless-stopped \
	  -v /root/letsencrypt/live/blog.pfarley.dev:/opt/letsencrypt/live/blog.pfarley.dev:ro \
	  -v /root/letsencrypt/archive/blog.pfarley.dev:/opt/letsencrypt/archive/blog.pfarley.dev:ro \
	  -v /root/certbot:/opt/certbot:ro \
	  blog \
	  nginx -g "daemon off;"

docker run --entrypoint /bin/sh \
	  -d --name "certbot" \
	  --restart unless-stopped \
           -v /root/certbot:/var/www:rw \
           -v /root/letsencrypt:/etc/letsencrypt:rw \
           certbot/certbot:v3.2.0 \
	  -c \
	  'while true; do
	  	certbot certonly --webroot --webroot-path /var/www \
			--cert-name blog.pfarley.dev \
           		-d pfarley.dev \
           		-d blog.pfarley.dev \
			--email pfarley@pfarley.dev \
			--agree-tos -n --keep-until-expiring \
			--expand \
			--preferred-challenges http
		sleep 86400
            done'
