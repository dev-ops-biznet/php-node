FROM php:7.4-fpm

# Oracle instantclient
ADD oracle/instantclient-basic-linux.x64-11.2.0.4.0.zip /tmp/instantclient-basic-linux.x64-11.2.0.4.0.zip
ADD oracle/instantclient-sdk-linux.x64-11.2.0.4.0.zip /tmp/instantclient-sdk-linux.x64-11.2.0.4.0.zip
ADD oracle/instantclient-sqlplus-linux.x64-11.2.0.4.0.zip /tmp/instantclient-sqlplus-linux.x64-11.2.0.4.0.zip
# SAP NWRFC
ADD sapnwrfc/nwrfc750P_6-70002752.zip /tmp/nwrfc750P_6-70002752.zip
ADD sapnwrfc/sap.ini /tmp/sap.ini

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN apt-get clean
RUN apt-get update -y
RUN apt-get install -y libaio-dev supervisor nano openssl unixodbc zip unzip git wget libfreetype6-dev libjpeg62-turbo-dev libpng-dev libldb-dev libldap2-dev unixodbc-dev libzip-dev gnupg2 apt-transport-https libssh2-1-dev libssh2-1 openssh-server \
    libxrender1 \
    libjpeg62-turbo \
    fontconfig \
    libxtst6 \
    xfonts-75dpi \
    xfonts-base \
    xz-utils

RUN curl "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb" -L -o "wkhtmltopdf.deb"
RUN dpkg -i wkhtmltopdf.deb

RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
RUN curl https://packages.microsoft.com/config/ubuntu/18.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
RUN apt-get update -yqq \
    && apt-get install -y --no-install-recommends openssl \ 
    && sed -i 's,^\(MinProtocol[ ]*=\).*,\1'TLSv1.0',g' /etc/ssl/openssl.cnf \
    && sed -i 's,^\(CipherString[ ]*=\).*,\1'DEFAULT@SECLEVEL=1',g' /etc/ssl/openssl.cnf\
    && rm -rf /var/lib/apt/lists/*
RUN apt-get update -y

RUN ACCEPT_EULA=Y apt-get install msodbcsql17
RUN ACCEPT_EULA=Y apt-get install mssql-tools
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
RUN echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
RUN echo 'export SAPNWRFC_HOME=/usr/local/nwrfcsdk' >> ~/.bash_profile
RUN echo 'export SAPNWRFC_HOME=/usr/local/nwrfcsdk' >> ~/.bashrc
RUN cat  ~/.bashrc
CMD source ~/.bashrc

RUN unzip /tmp/instantclient-basic-linux.x64-11.2.0.4.0.zip -d /usr/local/
RUN unzip /tmp/instantclient-sdk-linux.x64-11.2.0.4.0.zip -d /usr/local/
RUN unzip /tmp/instantclient-sqlplus-linux.x64-11.2.0.4.0.zip -d /usr/local/
RUN unzip /tmp/nwrfc750P_6-70002752.zip -d /usr/local/
RUN ln -s /usr/local/instantclient_11_2 /usr/local/instantclient
RUN ln -s /usr/local/instantclient/libclntsh.so.11.1 /usr/local/instantclient/libclntsh.so
RUN ln -s /usr/local/instantclient/sqlplus /usr/bin/sqlplus
RUN touch /etc/ld.so.conf.d/nwrfcsdk.conf
RUN echo '/usr/local/nwrfcsdk/lib' >> /etc/ld.so.conf.d/nwrfcsdk.conf
RUN ldconfig -p | grep sap

RUN cd /tmp && git clone https://github.com/gkralik/php7-sapnwrfc.git \
    && cd php7-sapnwrfc \
    && phpize \
    && ./configure \
    && make && make install

RUN echo 'instantclient,/usr/local/instantclient' | pecl install oci8-2.2.0

RUN docker-php-ext-install zip
RUN docker-php-ext-configure gd --with-jpeg
RUN docker-php-ext-install gd
RUN docker-php-ext-install pcntl
RUN docker-php-ext-install bcmath
RUN docker-php-ext-install ldap
RUN apt update && apt install libxml2-dev -y
RUN docker-php-ext-install soap
RUN docker-php-ext-install mysqli pdo pdo_mysql
RUN pecl install sqlsrv pdo_sqlsrv ssh2-1.2
RUN docker-php-ext-enable sqlsrv pdo_sqlsrv oci8 pcntl mysqli pdo pdo_mysql ssh2
RUN echo 'extension=sapnwrfc' >> /usr/local/etc/php/php.ini-development
RUN echo 'extension=sapnwrfc' >> /usr/local/etc/php/php.ini-production
RUN echo 'extension=sapnwrfc.so' >> /usr/local/etc/php/conf.d/docker-php-ext-sapnwrfc.ini
#upload
#Setting di repo bukan di image. biar dinamis
# RUN echo "upload_max_filesize = 10M\n" \
#          "post_max_size = 10M\n" \
#           > /usr/local/etc/php/conf.d/uploads.ini

# ssh2 This extension does not yet support PHP 7.3 (19 oct 2020)
# RUN cd /tmp \
#     && git clone https://git.php.net/repository/pecl/networking/ssh2.git \
#     && cd /tmp/ssh2/ \
#     && .travis/build.sh \
#     && docker-php-ext-enable ssh2

ADD php/oci8.ini /etc/php5/cli/conf.d/30-oci8.ini
ENV LD_LIBRARY_PATH=/usr/local/instantclient

RUN cd /tmp && git clone https://github.com/git-ftp/git-ftp.git && cd git-ftp \
    && tag="$(git tag | grep '^[0-9]*\.[0-9]*\.[0-9]*$' | tail -1)" \
    && git checkout "$tag" \
    && mv git-ftp /usr/local/bin && chmod +x /usr/local/bin

RUN docker-php-ext-install sockets

RUN pecl install -o -f redis \
&&  rm -rf /tmp/pear \
&&  docker-php-ext-enable redis

RUN curl -sL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install nodejs -y -f

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* /var/tmp/*

# Configure non-root user.
RUN groupmod -o -g 1000 www-data && \
    usermod -o -u 1000 -g www-data www-data

CMD ["php-fpm"]
EXPOSE 9000