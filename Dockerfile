FROM debian:bullseye-slim

LABEL maintainer "hieptran@bavaan.com"

ENV MYSQL_MAJOR 8.0
ENV MYSQL_VERSION 8.0.34-1debian11
ENV NVM_DIR /root/.nvm
ENV NODE_VERSION v16.17.0

# copy all filesystem relevant files
COPY fs /tmp/

# start install routine
RUN \

    # install base tools
    apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            vim less tar wget curl apt-transport-https ca-certificates apt-utils net-tools htop \
            xz-utils bzip2 openssl perl xz-utils zstd python3-pip pv software-properties-common dirmngr gnupg && \
    
    pip install setuptools wheel && \

    # copy repository files
    cp -r /tmp/etc/apt /etc && \

    # add repository keys
    apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys C2518248EEA14886 && \
    apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys EEA14886 && \
    apt-key adv --no-tty --keyserver keyserver.ubuntu.com --recv-keys 5072E1F5 && \
    curl https://packages.sury.org/php/apt.gpg | apt-key add - && \
    curl https://nginx.org/keys/nginx_signing.key | apt-key add - && \
    curl https://www.rabbitmq.com/rabbitmq-release-signing-key.asc | apt-key add - && \
    curl https://artifacts.elastic.co/GPG-KEY-elasticsearch | apt-key add - && \
    curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-erlang.E495BB49CC4BBE5B.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq.E495BB49CC4BBE5B.gpg > /dev/null && \
    curl -1sLf https://github.com/rabbitmq/signing-keys/releases/download/3.0/cloudsmith.rabbitmq-server.9F4587F226208342.key | gpg --dearmor | tee /usr/share/keyrings/rabbitmq.9F4587F226208342.gpg > /dev/null && \
    wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg && \
    wget -q -O - https://packages.blackfire.io/gpg.key | dd of=/usr/share/keyrings/blackfire-archive-keyring.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/blackfire-archive-keyring.asc] http://packages.blackfire.io/debian any main" | tee /etc/apt/sources.list.d/blackfire.list && \

    set -eux; \
    # gpg: key 3A79BD29: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
	key='859BE8D7C586F538430B19C2467B942D3A79BD29'; \
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
	mkdir -p /etc/apt/keyrings; \
	gpg --batch --export "$key" > /etc/apt/keyrings/mysql.gpg; \
	gpgconf --kill all; \
	rm -rf "$GNUPGHOME" && \

    # update repositories
    apt-get update && \

    # define deb selection configurations
    echo postfix postfix/mailname string dnmp | debconf-set-selections && \
    echo postfix postfix/main_mailer_type string 'Internet Site' | debconf-set-selections && \
    echo debconf shared/accepted-oracle-license-v1-1 select true | debconf-set-selections  && \
    echo debconf shared/accepted-oracle-license-v1-1 seen true | debconf-set-selections  && \

    # prepare compatibilities for docker
    dpkg-divert --rename /usr/lib/sysctl.d/elasticsearch.conf && \

    # install supervisor
    pip install supervisor && \
    pip install supervisor-stdout && \

    # install nvm and nodejs
    mkdir $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash && \
    /bin/bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm use --delete-prefix $NODE_VERSION" && \
    #/bin/bash -c "source $NVM_DIR/nvm.sh && npm install -g yarn pm2" && \

    # add our user and group first to make sure their IDs get assigned consistently,
    # regardless of whatever dependencies get added
    groupadd -r mysql && useradd -r -g mysql mysql && \

    # install packages
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --fix-missing \
        # general tools
        cron openssl rsync git graphicsmagick imagemagick ghostscript ack-grep postfix locales-all \
        # oracle java 8
        default-jre \
        # nginx
        nginx \
        # varnish
        varnish \
        # redis
        redis-server \
        # rabbitmq
        erlang-base \
        erlang-asn1 erlang-crypto erlang-eldap erlang-ftp erlang-inets \
        erlang-mnesia erlang-os-mon erlang-parsetools erlang-public-key \
        erlang-runtime-tools erlang-snmp erlang-ssl \
        erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl \
        rabbitmq-server \
        # elasticsearch
        elasticsearch \
        # php 8.1
        php8.1 php8.1-cli php8.1-common php8.1-fpm php8.1-curl php8.1-gd php8.1-mysql php8.1-soap \
        php8.1-zip php8.1-intl php8.1-bcmath php8.1-xsl php8.1-xml php8.1-mbstring php8.1-xdebug \
        php8.1-mongodb php8.1-ldap php8.1-imagick php8.1-readline php8.1-sqlite3 php8.1-apcu php8.1-amqp php8.1-redis php8.1-pgsql \
        # php 8.2
        php8.2 php8.2-cli php8.2-common php8.2-fpm php8.2-curl php8.2-gd php8.2-mysql php8.2-soap \
        php8.2-zip php8.2-intl php8.2-bcmath php8.2-xsl php8.2-xml php8.2-mbstring php8.2-xdebug \
        php8.2-mongodb php8.2-ldap php8.2-imagick php8.2-readline php8.2-sqlite3 php8.2-apcu php8.2-amqp php8.2-redis php8.2-pgsql \
        # blackfire
        blackfire \
        blackfire-php && \

    # define default php cli version
    update-alternatives --set php /usr/bin/php8.1 && \

    # mysql 8.0
    { \
		echo mysql-community-server mysql-community-server/data-dir select ''; \
		echo mysql-community-server mysql-community-server/root-pass password ''; \
		echo mysql-community-server mysql-community-server/re-root-pass password ''; \
		echo mysql-community-server mysql-community-server/remove-test-db select false; \
	} | debconf-set-selections \
	&& apt-get update \
	&& apt-get install -y \
		mysql-community-client="${MYSQL_VERSION}" \
		mysql-community-server-core="${MYSQL_VERSION}" \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -rf /var/lib/mysql && mkdir -p /var/lib/mysql /var/run/mysqld /var/log/mysql \
	&& chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql \
    # ensure that /var/run/mysqld (used for socket and lock files) is writable regardless of the UID our mysqld instance ends up having at runtime
	&& chmod 1777 /var/run/mysqld /var/lib/mysql /var/log/mysql && \

    # install elasticsearch plugins
    /usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-phonetic && \
    /usr/share/elasticsearch/bin/elasticsearch-plugin install analysis-icu && \

    # install composer
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \


    # copy provided fs files
    cp -r /tmp/usr / && \
    cp -r /tmp/etc / && \

    # setup filesystem
    mkdir -p /var/run/php && \
    chown -R mysql:mysql /var/lib/mysql /var/run/mysqld /var/log/mysql && \
    chmod 777 /var/run/mysqld /var/log/mysql && \
    chmod a+x /usr/local/bin/docker-entrypoint.sh && \

    # cleanup
    apt-get clean && \
    rm -rf /tmp/* /var/lib/apt/lists/*
COPY fs/etc/mysql/ /etc/mysql/
# define entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# define cmd
CMD ["supervisord", "--nodaemon", "-c", "/etc/supervisord.conf"]
