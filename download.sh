: ${PRO_URL=https://download.seafile.com/d/6e5297246c/?p=/pro}
: ${BASEPATH=/opt/haiwen}
: ${PRO:false}
: ${VERSION=latest}

if [ "$PRO" = true ] ; then
  echo "Installing Professional Edition..."
  pro_user_id=`echo $PRO_URL | ack -o '(?<=\/d\/)[a-z0-9]*(?=\/)'`
  pro_filename=$(curl -sL $PRO_URL \
    | ack -o '(?<=\")seafile-pro-server.*x86-64\.tar\.gz(?=\")'|sort -r|head -1)
  download_path="https://download.seafile.com/d/$pro_user_id/files/?p=/pro/$pro_filename&dl=1"
elif [ "$VERSION" = "latest" ] ; then
  echo "Installing Community Edition..."
  download_path=$(curl -sL https://www.seafile.com/en/download/ \
    | grep -oE 'https://.*seafile-server.*x86-64.tar.gz'|sort -r|head -1)
else
  echo "Installing Community Edition..."
  download_path="https://download.seadrive.org/seafile-server_${VERSION}_x86-64.tar.gz"
fi

echo "Downloading & Extracting $download_path..."
curl -sL $download_path | tar -C $BASEPATH -xz
chown -R seafile:seafile $BASEPATH
