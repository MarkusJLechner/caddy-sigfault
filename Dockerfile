# ╔════════════════════════════╗
# ║          PHP BASE          ║
# ╚════════════════════════════╝
# See updates https://hub.docker.com/_/php/tags
FROM dunglas/frankenphp:1.2.1-php8.3.9-bookworm AS php-base

ARG USER=sail

# As argument for mac users
ARG WKHTML_DEP_URI=https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb
ARG LIBSSL_DEP_URI=http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb
ARG NODE_VERSION=21
ARG USER=sail
ARG USER_ID=1000
ARG GROUP_ID=1000

# Set working directory
WORKDIR /var/www/web

# See https://frankenphp.dev/docs/docker/#running-as-a-non-root-user
# Also create home folder. npm and composer will install in the home cache folder
# libnss3-tools needed for caddy https certificate generation
RUN groupadd -g ${GROUP_ID} ${USER} \
    && useradd -u ${USER_ID} -g ${GROUP_ID} -m ${USER} \
    && setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp \
    && chown -R ${USER_ID}:${GROUP_ID} /data/caddy /config/caddy

# Install important libraries
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    curl \
    unzip

# Install PHP extensions
RUN IPE_GD_WITHOUTAVIF=1 install-php-extensions \
    # https://www.php.net/manual/en/intro.pcntl.php
        pcntl \
    # opcache: https://www.php.net/manual/en/intro.opcache.php - Caching
        opcache \
    # mysql driver - laravel
        pdo_mysql \
    # redis driver - laravel
        redis \
    # intl: https://www.php.net/manual/en/book.intl.php - Internationalization Functions
        intl \
    # soap: https://www.php.net/manual/en/book.soap.php - for A-Trust
        soap \
    # exif: https://www.php.net/manual/en/book.exif.php - Read EXIF headers from JPEG and TIFF
        exif \
    # gd: https://www.php.net/manual/en/book.image.php - Image processing and GD library
        gd \
    # zip: https://www.php.net/manual/en/book.zip.php - Zip File Archive Functions
        zip \
    # bcmath: https://www.php.net/manual/en/book.bc.php - Arbitrary precision mathematics
        bcmath

# Install Node.js and install frontend dependencies. npmrc is used to authenticate with mobiscroll
RUN apt-get update \
    && curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm -v \
    && node -v \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Download the wkhtmltopdf release from github and install to /usr/local/bin/wkhtmltopdf
RUN echo "Use wkhtml dep path: $WKHTML_DEP_URI" \
     && curl -L -o /tmp/libssl.deb $LIBSSL_DEP_URI \
     && dpkg -i /tmp/libssl.deb \
     && apt-get install --no-install-recommends -f -y \
     && rm -rf /var/lib/apt/lists/* /tmp/libssl.deb \
     && apt-get update \
     && apt-get install --no-install-recommends -y \
        # Necessary for merging background image with pdf
        qpdf \
        fontconfig \
        libfreetype6 \
        libjpeg62-turbo \
        libpng16-16 \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        xfonts-75dpi \
        xfonts-base \
     && curl -L -o /tmp/wkhtmltox.deb $WKHTML_DEP_URI \
     && dpkg -i /tmp/wkhtmltox.deb \
     && apt-get install --no-install-recommends -f -y \
     && rm -rf /var/lib/apt/lists/* /tmp/wkhtmltox.deb

# Get composer and install PHP dependencies
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Copy the rest of the application code. This is done after install for caching reasons
COPY . .

# ╔═══════════════════════════════╗
# ║          DEVELOPMENT          ║
# ╚═══════════════════════════════╝
FROM php-base AS development

# Todo Install debugging tools against segmentation faults (happened while running e2e against frankenphp image)
## Create the sysctl configuration file and add the ptrace setting
#RUN apt-get update && apt-get install -y procps
#RUN echo "kernel.yama.ptrace_scope = 0" > /etc/sysctl.d/10-ptrace.conf
## Reload sysctl settings
#RUN apt-get update && apt-get install -y gdb

# wget necessary for entrypoint mysql wait
# gettext necessary for sail npm i18n commands
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gettext \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy php.ini
#COPY --chown=${USER_ID}:${GROUP_ID} ./docker/webserver/php-development.ini "$PHP_INI_DIR/php.ini"

# Set entrypoint
COPY --chown=${USER_ID}:${GROUP_ID} ./docker/webserver/entrypoint-development.sh /var/www/entrypoint.sh
RUN chmod u+x /var/www/entrypoint.sh
ENTRYPOINT ["/var/www/entrypoint.sh"]

# Copy development caddy files
COPY --chown=${USER_ID}:${GROUP_ID} ./docker/webserver/development.caddy /etc/caddy/Caddyfile

# TODO for debugging
# goto github and download debugging build frankenphp-linux-x86_64-debug
# see https://github.com/dunglas/frankenphp/releases
#COPY --chown=${USER_ID}:${GROUP_ID}  ./frankenphp-linux-x86_64-debug /usr/local/bin/frankenphp
#RUN chmod +x /usr/local/bin/frankenphp

# Set non root user
USER ${USER}

# Start FrankenPHP server with config watch mode
CMD [ "frankenphp", "run", "--config", "/etc/caddy/Caddyfile", "--watch" ]

# TODO for debugging
# CMD ["tail", "-f", "/dev/null"]
