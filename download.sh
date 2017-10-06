: ${BASEPATH=/opt/haiwen}
: ${VERSION=latest}
: ${PRO=false}
: ${ARCH=`uname -p`}

ARCH="${ARCH/_/-}"
get_url_cmd="/usr/local/bin/seafile_download_url --version $VERSION --arch $ARCH"

echo   "Generating download URL for:"
echo   "  VERSION: $VERSION"
echo   "  ARCHITECTURE: $ARCH"
printf "  EDITION: "

if [ "$PRO" = true ] ; then
  echo "Professional"
  $get_url_cmd="$get_url_cmd --pro"
else
  echo "Community"
fi

download_url=`$get_url_cmd`

if [ $? -ne 0 ] ; then
  echo "ERROR: Could not obtain download URL. Aborting."
  exit 1
else
  echo ""
  if [ "$PRO" = true ] ; then
    echo "Installing Professional Edition..."
  else
    echo "Installing Community Edition..."
  fi

  echo ""
  echo "Downloading & Extracting $download_url..."
  curl -sL $download_url | tar -C $BASEPATH -xz
  chown -R seafile:seafile $BASEPATH

  echo ""
  echo "Done!"
fi
