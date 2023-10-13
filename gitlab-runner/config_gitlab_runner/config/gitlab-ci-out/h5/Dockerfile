FROM docker.io/nginx:1.25-alpine
WORKDIR /usr/share/nginx/html
COPY default.conf  /etc/nginx/conf.d/default.conf
COPY . .
RUN rm -rf .git .gitlab-ci.yml Dockerfile default.conf