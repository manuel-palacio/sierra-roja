# Serves the exported game (build/web, made by ops/build-web.sh) as static files.
FROM nginx:1.27-alpine
COPY ops/nginx.conf /etc/nginx/conf.d/default.conf
COPY build/web/ /usr/share/nginx/html/
COPY CREDITS.md /usr/share/nginx/html/credits.txt
