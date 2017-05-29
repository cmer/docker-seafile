DEBIAN_FRONTEND=noninteractive apt-get update \
  && apt-get install -y locales python2.7 libpython2.7 python-mysqldb \
      python-setuptools python-dev python-pip python-imaging python-ldap \
      python-urllib3 sqlite3 python-memcache curl ack-grep libnss3 \
      openjdk-8-jre poppler-utils ffmpeg libmemcached-dev libz-dev \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && pip install --upgrade pip \
  && pip install pillow moviepy pylibmc django-pylibmc

useradd -d /seafile -M -s /bin/bash -c "Seafile User" seafile
mkdir -p /opt/haiwen /seafile/
chown -R seafile:seafile /seafile /opt/haiwen

locale-gen en_US.UTF-8
echo "LC_ALL=en_US.UTF-8\nLANG=en_US.UTF-8" >> /etc/default/locale
