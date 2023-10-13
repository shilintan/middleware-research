FROM docker.io/nginx:1.25-alpine
COPY dist /usr/share/nginx/html
COPY default.conf  /etc/nginx/conf.d/default.conf
RUN rm -rf  /usr/share/nginx/html/Dockerfile &&  rm -rf  /usr/share/nginx/html/default.conf