FROM php:8.3.37-fpm-bookworm

LABEL maintainer="liyang <654516092@qq.com>"
LABEL org.opencontainers.image.source="devilbox/docker-php-fpm"
LABEL org.opencontainers.image.vendor="devilbox"

# ========== 全局环境变量 ==========
ENV TZ=Asia/Shanghai
ENV DEBIAN_FRONTEND=noninteractive
ENV LD_LIBRARY_PATH=/opt/oracle/instantclient

WORKDIR /var/www/html

# ========== 安装系统依赖 ==========
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends --no-install-suggests \
        git curl wget ca-certificates \
        libaio-dev libbz2-dev libc-client-dev libcurl4-openssl-dev \
        libenchant-2-dev libevent-dev libfreetype6-dev libgmp-dev \
        libicu-dev libjpeg-dev libkrb5-dev libldap2-dev \
        libpng-dev libpq-dev libsasl2-dev libssl-dev libtidy-dev \
        libwebp-dev libxml2-dev libxslt-dev libzip-dev libonig-dev \
		liblz4-dev libvips-dev libc-ares-dev libpcre3-dev \
		libmagickwand-dev zlib1g-dev liblzf-dev libmemcached-dev librabbitmq-dev librdkafka-dev libyaml-dev libzstd-dev \
        libsqlite3-dev libpspell-dev libsnmp-dev libssh2-1-dev libonig-dev libc-client-dev libicu-dev \
        pkg-config \
        unzip socat libfcgi-bin; \
        rm -rf /var/lib/apt/lists/*

# ========== PEAR 配置 ==========
RUN set -eux; \
    pear config-set preferred_state stable; \
    pecl config-set preferred_state stable; \
    pear config-show; pecl config-show

# ========== 内置PHP扩展 ==========
RUN set -eux; \
    docker-php-ext-configure gd --enable-gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" \
        bcmath \
        bz2 \
        calendar \
        dba \
        exif \
        gd \
        gettext \
        gmp \
        intl \
        ldap \
        mbstring \
        opcache \
        pcntl \
        pdo_mysql \
        pdo_pgsql \
        pgsql \
        shmop \
        sockets \
        sysvmsg \
        sysvsem \
        sysvshm \
        tidy \
        xsl \
        zip		

# imagick vips xlswriter
RUN set -eux; \
    pecl install imagick; \
	pecl install vips; \
	pecl install xlswriter; \
    docker-php-ext-enable imagick vips xlswriter;
		
# curl ftp fileinfo mysqli soap pdo_sqlite sqlite3 pspell snmp imap		
RUN set -eux; \
    docker-php-ext-install -j$(nproc) \
    curl \
    ftp \
    fileinfo \
    mysqli \
    soap \
    pspell \
    snmp

# ========== 源码编译 lz4 ==========
# 需要再github上离线下载：https://github.com/kjdev/php-ext-lz4/tags
COPY ./php-ext-lz4 /tmp/php-ext-lz4
RUN set -eux; \
    cd /tmp/php-ext-lz4; \
    phpize; \
    ./configure --with-lz4-includedir=/usr; \
    make -j$(nproc); \
    make install; \
    docker-php-ext-enable lz4; \
	rm -rf /tmp/php-ext-lz4

# ========== PECL扩展（移除lz4，顺序：igbinary → msgpack → redis/memcached） ==========
RUN set -eux; \
    pecl install igbinary; \
    pecl install msgpack; \
	pecl install apcu; \
	pecl install uploadprogress; \
	pecl install yaml; \
	pecl install zstd; \
    docker-php-ext-enable igbinary msgpack apcu uploadprogress yaml zstd;

# ========== 源码安装redis/memcached ==========
RUN set -eux; \
    pecl config set mirror https://mirrors.aliyun.com/pecl/; \
    # memcached 源码编译（依赖libmemcached-dev）
    pecl download memcached; \
    tar -xf memcached*.tgz; \
    cd memcached-*/; \
    phpize; \
    ./configure --enable-memcached --enable-memcached-sasl --enable-memcached-igbinary --enable-memcached-msgpack --enable-memcached-json --enable-memcached-session; \
    make -j$(nproc); make install; cd ..; rm -rf memcached-*.tgz memcached-*/; \
    # redis 6.3.0 源码编译
    pecl download redis-6.3.0; \
    tar -xf redis-6.3.0.tgz; \
    cd redis-6.3.0; \
    phpize; \
    ./configure --enable-redis-igbinary --enable-redis-msgpack --enable-redis-lzf --enable-redis-lz4 --enable-redis-zstd --with-liblz4=/usr; \
    make -j$(nproc); make install; cd ..; rm -rf redis-6.3.0.tgz redis-6.3.0; \
    docker-php-ext-enable memcached redis
	
# imap
RUN set -eux; \
    docker-php-ext-configure imap --with-imap --with-imap-ssl --with-kerberos; \
    docker-php-ext-install -j$(nproc) imap
	
# mongodb;amqp; 
RUN set -eux; \
	pecl install mongodb; \
	pecl install amqp; \
    docker-php-ext-enable mongodb amqp;

# rdkafka ssh2 uuid
RUN set -eux; \
    pecl install rdkafka; \
	pecl install ssh2; \
	pecl install uuid; \
    docker-php-ext-enable rdkafka ssh2 uuid;
		

# swoole扩展
RUN set -eux; \
    pecl install --configureoptions 'enable-swoole-curl="yes" enable-mysqlnd="yes" enable-zstd="yes" enable-sockets="yes"' swoole; \
    docker-php-ext-enable swoole

# ========== Composer ==========
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
RUN composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/

# ========== php.ini 基础配置 ==========
RUN set -eux; \
    cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"; \
    sed -i 's/^;date.timezone =/date.timezone = Asia\/Shanghai/g' "$PHP_INI_DIR/php.ini"; \
    sed -i 's/^opcache.enable=0/opcache.enable=1/g' "$PHP_INI_DIR/php.ini"; \
	sed -i 's/^;opcache.memory_consumption=.*/opcache.memory_consumption=128/g' "$PHP_INI_DIR/php.ini"; \
	sed -i 's/^;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=100000/g' "$PHP_INI_DIR/php.ini"; \
    sed -i 's/^;opcache.validate_timestamps=.*/opcache.validate_timestamps=0/g' "$PHP_INI_DIR/php.ini";

# ========== FPM健康检查 ==========
HEALTHCHECK --interval=60s --timeout=3s --retries=3 \
    CMD cgi-fcgi -bind -connect 127.0.0.1:9000 || exit 1

EXPOSE 9000
CMD ["php-fpm"]
