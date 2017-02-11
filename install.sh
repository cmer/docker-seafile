useradd -d /seafile -M -s /bin/bash -c "Seafile User" seafile
mkdir -p /opt/haiwen /seafile/
chown -R seafile:seafile /seafile /opt/haiwen

locale-gen en_US.UTF-8
echo "LC_ALL=en_US.UTF-8\nLANG=en_US.UTF-8" >> /etc/default/locale



