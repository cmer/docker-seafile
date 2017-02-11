FROM m3adow/ubuntu_dumb-init_gosu:latest
MAINTAINER Carl Mercier <foss@carlmercier.com>

RUN DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install -y python2.7 libpython2.7 python-mysqldb \
      python-setuptools python-pip python-imaging python-ldap \
      python-urllib3 sqlite3 python-memcache curl ack-grep libnss3 \
      openjdk-8-jre poppler-utils \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# RUN pip install pylibmc django-pylibmc

COPY ["install.sh", "/tmp/"]
COPY ["download.sh", "/usr/local/bin/"]
COPY ["seafile-entrypoint.sh", "/usr/local/bin/"]

RUN /tmp/install.sh

EXPOSE 8000 8082
VOLUME /seafile

ENV SEAFILE_NAME=Seafile
ENV SEAFILE_ADDRESS=127.0.0.1
ENV SEAFILE_ADMIN=admin@example.org
ENV SEAFILE_ADMIN_PW=
ENV PRO=false
ENV FORCE_PERMISSIONS=false

ENTRYPOINT ["/usr/bin/dumb-init", "/usr/local/bin/seafile-entrypoint.sh"]
