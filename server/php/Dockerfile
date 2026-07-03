FROM php:8.5-fpm-alpine

ENV TZ=UTC

RUN apk add --no-cache --virtual .build-deps $PHPIZE_DEPS linux-headers \
 && docker-php-ext-install pdo_mysql \
 && pecl install xdebug timezonedb \
 && docker-php-ext-enable xdebug timezonedb \
 && apk del .build-deps \
 && apk add --no-cache unzip

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN mv $PHP_INI_DIR/php.ini-development $PHP_INI_DIR/php.ini

COPY php.ini $PHP_INI_DIR/conf.d/zz-app.ini
