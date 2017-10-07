: ${BASEPATH=/opt/haiwen}
: ${VERSION=latest}
: ${PRO=false}
: ${ARCH=`uname -p`}

ARCH="${ARCH/_/-}"

echo   "Generating download URL for:"
echo   "  VERSION: $VERSION"
echo   "  ARCHITECTURE: $ARCH"
printf "  EDITION: "

if [ "$PRO" = true ] ; then
  echo "Professional"
  get_url_cmd="/usr/local/bin/seafile_download_url --quiet --version $VERSION --arch $ARCH --pro"
else
  echo "Community"
  get_url_cmd="/usr/local/bin/seafile_download_url --quiet --version $VERSION --arch $ARCH"
fi

download_url=`$get_url_cmd`

if [[ $? -ne 0 ]] ; then
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
