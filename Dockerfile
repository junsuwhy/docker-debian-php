FROM netivism/docker-debian-base
MAINTAINER Jimmy Huang <jimmy@netivism.com.tw>

ENV \
  COMPOSER_HOME=/root/.composer \
  PATH=/root/.composer/vendor/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#mariadb
WORKDIR /etc/apt/sources.list.d
RUN \
    apt-get update && \
    apt-get install -y apt-transport-https wget gnupg && \
    echo "deb https://packages.sury.org/php/ stretch main" > phpsury.list && \
    echo "deb-src https://packages.sury.org/php/ stretch main" >> phpsury.list && \
    wget https://packages.sury.org/php/apt.gpg  && apt-key add apt.gpg && rm -f apt.gpg && \
    apt-get update && \
    apt-get install -y wget mariadb-server gcc make autoconf libc-dev pkg-config


WORKDIR /
RUN \
  apt-get install -y \
    rsyslog \
    php7.2 \
    php7.2-curl \
    php7.2-imap \
    php7.2-gd \
    php7.2-mysql \
    php7.2-mbstring \
    php7.2-xml \
    php7.2-memcached \
    php7.2-cli \
    php7.2-fpm \
    php7.2-zip \
    curl \
    vim \
    git-core

RUN \
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
  composer global require drush/drush:8.3.0 && \
  cd /root/.composer && \
  find . | grep .git | xargs rm -rf && \
  composer clearcache

RUN apt-get install -y supervisor procps

# wkhtmltopdf
WORKDIR /tmp
RUN \
  apt-get install -y fonts-noto-cjk fontconfig ca-certificates fontconfig libc6 libfreetype6 libjpeg62-turbo libpng16-16 libssl1.1 libstdc++6 libx11-6 libxcb1 libxext6 libxrender1 xfonts-75dpi xfonts-base zlib1g && \
  wget -nv https://downloads.wkhtmltopdf.org/0.12/0.12.5/wkhtmltox_0.12.5-1.stretch_amd64.deb -O wkhtmltox.deb && \
  dpkg -i wkhtmltox.deb && \
  rm -f wkhtmltox.deb

# php mcrypt
RUN \
  apt-get install -y php-pear gcc make autoconf libc-dev pkg-config php7.2-dev libmcrypt-dev && \
  printf "\n" | pecl install mcrypt-1.0.1 && \
  bash -c "echo extension=/usr/lib/php/20170718/mcrypt.so > /etc/php/7.2/mods-available/mcrypt.ini" && \
  bash -c "phpenmod mcrypt"

# apache2 & xdebug
RUN \
  apt-get update && \
  apt-get install -y \
    apache2 \ 
    libapache2-mod-php7.2

RUN \ 
  pecl install -f xdebug && \ 
  echo "zend_extension=$(find /usr/lib/ -name xdebug.so)" > /etc/php/7.2/apache2/conf.d/xdebug.ini

RUN \
  apt-get remove -y php7.2-dev gcc make autoconf libc-dev pkg-config php-pear && \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/*

### PHP FPM Config
# remove default enabled site
RUN \
  mkdir -p /var/www/html/log/supervisor && \
  git clone https://github.com/NETivism/docker-sh.git /home/docker && \
  cp -f /home/docker/php/default72.ini /etc/php/7.2/docker_setup.ini && \
  ln -s /etc/php/7.2/docker_setup.ini /etc/php/7.2/fpm/conf.d/ && \
  cp -f /home/docker/php/default72_cli.ini /etc/php/7.2/cli/conf.d/ && \
  cp -f /home/docker/php/default_opcache_blacklist /etc/php/7.2/opcache_blacklist && \
  sed -i 's/^listen = .*/listen = 80/g' /etc/php/7.2/fpm/pool.d/www.conf && \
  sed -i 's/^pm = .*/pm = ondemand/g' /etc/php/7.2/fpm/pool.d/www.conf && \
  sed -i 's/;daemonize = .*/daemonize = no/g' /etc/php/7.2/fpm/php-fpm.conf && \
  sed -i 's/^pm\.max_children = .*/pm.max_children = 8/g' /etc/php/7.2/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.process_idle_timeout = .*/pm.process_idle_timeout = 15s/g' /etc/php/7.2/fpm/pool.d/www.conf && \
  sed -i 's/^;pm\.max_requests = .*/pm.max_requests = 50/g' /etc/php/7.2/fpm/pool.d/www.conf && \
  sed -i 's/^;request_terminate_timeout = .*/request_terminate_timeout = 7200/g' /etc/php/7.2/fpm/pool.d/www.conf

ADD container/mysql/mysql-init.sh /usr/local/bin/mysql-init.sh
ADD container/rsyslogd/rsyslog.conf /etc/rsyslog.conf
ADD container/supervisord/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD container/php/php.ini /etc/php/7.2/apache2/php.ini
ADD container/apache2/000-default.conf /etc/apache2/sites-available/000-default.conf

RUN \ 
  a2enmod rewrite && \
  service apache2 restart

### END
WORKDIR /var/www/html
ENV TERM=xterm
CMD ["/usr/bin/supervisord"]
