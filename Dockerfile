FROM debian:latest as build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2                                                  \
        apache2-utils                                            \
        autoconf                                                 \
        automake                                                 \
        bc                                                       \
        build-essential                                          \
        dc                                                       \
        gawk                                                     \
        gcc                                                      \
        gettext                                                  \
        libc6                                                    \
        libgd-dev                                                \
        libmcrypt-dev                                            \
        libnet-snmp-perl                                         \
        libssl-dev                                               \
        make                                                     \
        openssl                                                  \
        php                                                      \
        snmp                                                     \
        unzip                                                    \
        wget &&                                                  \
        rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN wget --no-check-certificate -O nagioscore.tar.gz                                    \
        https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.14.tar.gz && \
        tar xzvf nagioscore.tar.gz &&                                                   \
        cd /tmp/nagioscore-nagios-4.4.14 &&                                             \
        ./configure --with-httpd-conf=/etc/apache2/sites-enabled &&                     \
        make -j$(nproc) all


WORKDIR /tmp

RUN wget --no-check-certificate -O                                                                             \
        nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.4.6.tar.gz && \
        tar zxf nagios-plugins.tar.gz &&                                                                       \
        cd /tmp/nagios-plugins-release-2.4.6/ &&                                                               \
        ./tools/setup &&                                                                                       \
        ./configure &&                                                                                         \
        make -j$(nproc)


FROM debian:latest

# VOLUME [ "/usr/local/nagios/etc/", "/usr/local/nagios/var/" ]
EXPOSE 80 443
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2                                                  \
        apache2-utils                                            \
        build-essential                                          \
        make                                                     \
        libssl-dev                                               \
        openssl                                                  \
        php                                                      \
        snmp &&                                                  \
        rm -rf /var/lib/apt/lists/*


COPY --from=build /tmp/nagioscore-nagios-4.4.14 /tmp/nagioscore
COPY --from=build /tmp/nagios-plugins-release-2.4.6 /tmp/nagiosplugins

WORKDIR /tmp/nagioscore

RUN make install-groups-users &&         \
        make install &&                  \
        make install-daemoninit &&       \
        make install-commandmode &&      \
        make install-config &&           \
        make install-webconf &&          \
        a2enmod rewrite &&               \
        a2enmod cgi &&                   \
        usermod -a -G nagios www-data && \
        htpasswd -bc /usr/local/nagios/etc/htpasswd.users nagiosadmin password

WORKDIR /tmp/nagiosplugins
RUN make install

WORKDIR /
RUN rm -rf /tmp/*

CMD service nagios start && apachectl -D FOREGROUND
