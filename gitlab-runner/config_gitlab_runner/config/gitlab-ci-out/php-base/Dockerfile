FROM php:7.3-fpm
WORKDIR /app
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
RUN set -ex \
    && echo "--- updating mirror ---" \
    && sed -i 's#deb.debian.org#mirrors.163.com#g' /etc/apt/sources.list && sed -i 's#security.debian.org#mirrors.163.com#g' /etc/apt/sources.list && apt -y update \
    && echo "--- ------------------installing extension------------------ ---" \
    && php-fpm -v \
    && echo "--- installing exif ---" \
    && docker-php-ext-install exif \
    && echo "--- installing redis ---" \
    && apt-get -y install libzstd-dev \
    && yes| pecl install igbinary && docker-php-ext-enable igbinary \
    && yes| pecl install redis-5.3.4 && docker-php-ext-enable redis \
    && echo "--- installing operate tools ---" \
    && apt-get -y install procps net-tools \
    && echo "--- installing project ---" \
    && docker-php-ext-install mysqli pdo pdo_mysql opcache pcntl bcmath \
    && apt-get -y install libzip-dev zip && docker-php-ext-install zip \
    && echo "--- installing gd ---" \
    && apt-get -y install  libfreetype6-dev  libjpeg62-turbo-dev  libpng-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ --with-png-dir=/usr/include/ && docker-php-ext-install -j$(nproc) gd \
    && php -m \
    && echo "--- installing nginx ---" \
    && apt install -y nginx && nginx -v \
    && echo "installed"
