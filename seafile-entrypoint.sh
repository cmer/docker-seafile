#!/bin/bash
set -e
set -u
set -o pipefail

DATADIR=${DATADIR:-"/seafile"}
BASEPATH=${BASEPATH:-"/opt/haiwen"}
PRO=${PRO:-false}
LICENSE_FILE=$DATADIR/seafile-license.txt

/usr/local/bin/download.sh

if [ "$PRO" = true ] ; then
  echo "Using Professional Edition..."
  INSTALLPATH=${INSTALLPATH:-"${BASEPATH}/$(ls -1vr ${BASEPATH} | grep -E -m 1 '^seafile-pro-server-[0-9.-]+')"}

  if [ -f $LICENSE_FILE ]; then
    echo "Copying license: $LICENSE_FILE to $BASEPATH/"
    cp $LICENSE_FILE $BASEPATH/
  fi
else
  echo "Using Community Edition..."
  INSTALLPATH=${INSTALLPATH:-"${BASEPATH}/$(ls -1vr ${BASEPATH} | grep -E -m 1  '^seafile-server-[0-9.-]+')"}
fi

echo "Installation path: $INSTALLPATH"

trapped() {
  control_seahub "stop"
  control_seafile "stop"
}

autorun() {
  # If there's an existing seafile config, link the dirs
  move_and_link
  migrate_to_pro

  # Needed to check the return code
  set +e
  control_seafile "start"
  local RET=$?
  set -e
  # Try an initial setup on error
  if [ ${RET} -eq 255 ]
  then
    choose_setup
    control_seafile "start"
  elif [ ${RET} -gt 0 ]
  then
    exit 1
  fi
  if [ ${SEAFILE_FASTCGI:-} ]
  then
    control_seahub "start-fastcgi"
  else
    control_seahub "start"
  fi
  keep_in_foreground
}

run_only() {
  local SH_DB_DIR="${DATADIR}/${SEAHUB_DB_DIR}"
  # Linking must always be done
  link_files "${SH_DB_DIR}"
  control_seafile "start"
  control_seahub "start"
  keep_in_foreground
}

choose_setup() {
  set +u
  # If $MYSQL_SERVER is set, we assume MYSQL setup is intended,
  # otherwise sqlite
  if [ -n "${MYSQL_SERVER}" ]
  then
    set -u
    setup_mysql
  else
    set -u
    setup_sqlite
  fi
  sleep 300
}

setup_mysql() {
  echo "setup_mysql"

  # Wait for MySQL to boot up
  DOCKERIZE_TIMEOUT=${DOCKERIZE_TIMEOUT:-"60s"}
  dockerize -timeout ${DOCKERIZE_TIMEOUT} -wait tcp://${MYSQL_SERVER}:${MYSQL_PORT:-3306}

  set +u
  OPTIONAL_PARMS="$([ -n "${MYSQL_ROOT_PASSWORD}" ] && printf '%s' "-r ${MYSQL_ROOT_PASSWORD}")"
  set -u

  gosu seafile bash -c ". /tmp/seafile.env; ${INSTALLPATH}/setup-seafile-mysql.sh auto \
    -n "${SEAFILE_NAME}" \
    -i "${SEAFILE_ADDRESS}" \
    -p "${SEAFILE_PORT}" \
    -d "${SEAFILE_DATA_DIR}" \
    -o "${MYSQL_SERVER}" \
    -t "${MYSQL_PORT:-3306}" \
    -u "${MYSQL_USER}" \
    -w "${MYSQL_USER_PASSWORD}" \
    -q "${MYSQL_USER_HOST:-"%"}" \
    ${OPTIONAL_PARMS}"

  setup_seahub
  move_and_link
}

setup_sqlite() {
  echo "setup_sqlite"
  # Setup Seafile
  gosu seafile bash -c ". /tmp/seafile.env; ${INSTALLPATH}/setup-seafile.sh auto \
    -n "${SEAFILE_NAME}" \
    -i "${SEAFILE_ADDRESS}" \
    -p "${SEAFILE_PORT}" \
    -d "${SEAFILE_DATA_DIR}""

  setup_seahub
  move_and_link
}

setup_seahub() {
  # Setup Seahub

  # From https://github.com/haiwen/seafile-server-installer-cn/blob/master/seafile-server-ubuntu-14-04-amd64-http
  sed -i 's/= ask_admin_email()/= '"\"${SEAFILE_ADMIN}\""'/' ${INSTALLPATH}/check_init_admin.py
  sed -i 's/= ask_admin_password()/= '"\"${SEAFILE_ADMIN_PW}\""'/' ${INSTALLPATH}/check_init_admin.py

  control_seafile "start"

  gosu seafile bash -c ". /tmp/seafile.env; python -t ${INSTALLPATH}/check_init_admin.py"
  # gosu seafile bash -c ". /tmp/seafile.env; python -m trace -t ${INSTALLPATH}/check_init_admin.py | tee -a /seafile/check_init_admin.log"
}

move_and_link() {
  # As seahub.db is normally in the root dir of seafile (/opt/haiwen)
  # SEAHUB_DB_DIR needs to be defined if it should be moved elsewhere under /seafile
  local SH_DB_DIR="${DATADIR}/${SEAHUB_DB_DIR}"
  # Stop Seafile/hub instances if running
  control_seahub "stop"
  control_seafile "stop"

  move_files "${SH_DB_DIR}"
  link_files "${SH_DB_DIR}"

  # This is slow. Don't force permissions needlessly
  if [ "$FORCE_PERMISSIONS" = true ] ; then
    echo "Changing ownership of $DATADIR. Please be patient, this could take a while..."
    # SLOW:
    # chown -R seafile:seafile ${DATADIR}/
    # LESS SLOW:
    find $DATADIR -not -user seafile -execdir chown seafile:seafile {} \+
  fi
}

move_files() {
  for SEADIR in "ccnet" "conf" "seafile-data" "seahub-data"
  do
    if [ -e "${BASEPATH}/${SEADIR}" -a ! -L "${BASEPATH}/${SEADIR}" ]
    then
      cp -a ${BASEPATH}/${SEADIR} ${DATADIR}
      rm -rf "${BASEPATH}/${SEADIR}"
    fi
  done

  if [ -e "${BASEPATH}/seahub.db" -a ! -L "${BASEPATH}/seahub.db" ]
  then
    mv ${BASEPATH}/seahub.db ${1}/
  fi
}

link_files() {
  for SEADIR in "ccnet" "conf" "seafile-data" "seahub-data"
  do
    if [ -e "${DATADIR}/${SEADIR}" ]
    then
      ln -sf ${DATADIR}/${SEADIR} ${BASEPATH}/${SEADIR}
    fi
  done

  if [ -e "${SH_DB_DIR}/seahub.db" -a ! -L "${BASEPATH}/seahub.db" ]
  then
    ln -s ${1}/seahub.db ${BASEPATH}/seahub.db
  fi

}

keep_in_foreground() {
  # As there seems to be no way to let Seafile processes run in the foreground we
  # need a foreground process. This has a dual use as a supervisor script because
  # as soon as one process is not running, the command returns an exit code >0
  # leading to a script abortion thanks to "set -e".
  while true
  do
    for SEAFILE_PROC in "seafile-control" "ccnet-server" "seaf-server" "gunicorn"
    do
      pkill -0 -f "${SEAFILE_PROC}"
      sleep 1
    done
    sleep 5
  done
}

prepare_env() {
  cat << _EOF_ > /tmp/seafile.env
  export LANG='en_US.UTF-8'
  export LC_ALL='en_US.UTF-8'
  export CCNET_CONF_DIR="${BASEPATH}/ccnet"
  export SEAFILE_CONF_DIR="${SEAFILE_DATA_DIR}"
  export SEAFILE_CENTRAL_CONF_DIR="${BASEPATH}/conf"
  export PYTHONPATH=${INSTALLPATH}/seafile/lib/python2.6/site-packages:${INSTALLPATH}/seafile/lib64/python2.6/site-packages:${INSTALLPATH}/seahub:${INSTALLPATH}/seahub/thirdpart:${INSTALLPATH}/seafile/lib/python2.7/site-packages:${INSTALLPATH}/seafile/lib64/python2.7/site-packages:${PYTHONPATH:-}

_EOF_
}

control_seafile() {
  gosu seafile bash -c ". /tmp/seafile.env; ${INSTALLPATH}/seafile.sh "$@""
  local RET=$?
  sleep 1
  return ${RET}
}

control_seahub() {
  gosu seafile bash -c ". /tmp/seafile.env; ${INSTALLPATH}/seahub.sh "$@""
  local RET=$?
  sleep 1
  return ${RET}
}

migrate_to_pro() {
  # https://manual.seafile.com/deploy_pro/migrate_from_seafile_community_server.html
  migrated_to_pro_file=$DATADIR/.migrated_to_pro
  if [ $PRO = true ] && [ ! -f $DATADIR/.migrated_to_pro ]; then
    . /tmp/seafile.env
    echo | $INSTALLPATH/pro/pro.py setup --migrate
    touch $migrated_to_pro_file
  fi
}

# Fill vars with defaults if empty
MODE=${1:-"run"}

SEAFILE_DATA_DIR=${SEAFILE_DATA_DIR:-"${DATADIR}/seafile-data"}
SEAFILE_PORT=${SEAFILE_PORT:-8082}
SEAHUB_DB_DIR=${SEAHUB_DB_DIR:-}

prepare_env

trap trapped SIGINT SIGTERM
case $MODE in
  "autorun" | "run")
    autorun
  ;;
  "setup" | "setup_mysql")
    setup_mysql
  ;;
  "setup_sqlite")
    setup_sqlite
  ;;
  "setup_seahub")
    setup_seahub
  ;;
  "setup_only")
    choose_setup
  ;;
  "run_only")
    run_only
  ;;
esac
