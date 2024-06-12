#!/bin/bash

sync_directories() {
  echo "$(date +%s) : Attempting directory sync"
  if [ -z "${REMOTE_PASS}" ]; then
    echo "Doing it through rsync"
    rsync -avz --delete --exclude-from="${EXCLUDE_FILE}" -e "ssh" "$LOCAL_DIR" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
  else
    echo "Doing it through sshpass"
    sshpass -p "${REMOTE_PASS}" rsync -avz --delete --exclude-from="${EXCLUDE_FILE}" -e "ssh" "$LOCAL_DIR" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
  fi
}

show_help() {
  cat <<- EOF
Usage: ssh-sync-folders [OPTIONS]

Options:
  -l [DIR]           Local directory to be synced (default: current directory)
  -u [USER]          Remote SSH user
  -p [PASSWORD]      Remote SSH password (optional)
  -h [HOST]          Remote SSH host
  -d [DIR]           Remote directory to sync to (default: /shared)
  -e [PATTERNS]      Comma-separated list of file/folder patterns to exclude
  --help             Show this help message and exit

EOF
}

while getopts ":l:u:p:h:d:e:" arg; do
  case "${arg}" in
    l)
      LOCAL_DIR=${OPTARG}
      echo "LOCAL_DIR is ${LOCAL_DIR}"
      ;;
    u)
      REMOTE_USER=${OPTARG}
      echo "REMOTE_USER is ${REMOTE_USER}"
      ;;
    p)
      REMOTE_PASS=${OPTARG}
      echo "REMOTE_PASS is ${REMOTE_PASS}"
      ;;
    h)
      REMOTE_HOST=${OPTARG}
      echo "REMOTE_HOST is ${REMOTE_HOST}"
      ;;
    d)
      REMOTE_DIR=${OPTARG}
      echo "REMOTE_DIR is ${REMOTE_DIR}"
      ;;
    e)
      EXCLUDE_PATTERNS=${OPTARG}
      echo "EXCLUDE_PATTERNS is ${EXCLUDE_PATTERNS}"
      ;;
    help)
      show_help
      exit 0
      ;;
    *)
      echo "Invalid option: ${1}. Run with --help for usage information." >&2
      exit 1
      ;;
  esac
done

LOCAL_DIR=${LOCAL_DIR:-${SSH_SYNC_LOCAL_DIR:-$PWD}}
REMOTE_USER=${REMOTE_USER:-${SSH_SYNC_REMOTE_USER}}
REMOTE_PASS=${REMOTE_PASS:-${SSH_SYNC_REMOTE_PASS}}
REMOTE_HOST=${REMOTE_HOST:-${SSH_SYNC_REMOTE_HOST}}
REMOTE_DIR=${REMOTE_DIR:-${SSH_SYNC_REMOTE_DIR:-/ssh-sync}}

EXCLUDE_FILE=$(mktemp)
IFS=',' read -ra EXCLUDE_PATTERNS_ARRAY <<< "${EXCLUDE_PATTERNS:-${SSH_SYNC_EXCLUDE_PATTERNS}}"
for pattern in "${EXCLUDE_PATTERNS_ARRAY[@]}"; do
  echo "${pattern}" >> "${EXCLUDE_FILE}"
done

if [ -z "${LOCAL_DIR}" ] || [ -z "${REMOTE_USER}" ] || [ -z "${REMOTE_HOST}" ]; then
  echo "All arguments or environment variables (except remote directory, remote password, and exclude patterns) are required." >&2
  exit 1
fi

echo "Running initial sync, local dir: $LOCAL_DIR; remote dir: $REMOTE_DIR"
sync_directories
sync_result=$?

if [ $sync_result -ne 0 ]; then
  echo "Initial sync failed. Exiting."
  exit 1
fi

echo "Initial sync done."

echo "[ :::::::::::::::::::::::::::::::::::::::::::::::::::::::::: ]"
echo "[ ::::::::::::::::: Listening to Changes ::::::::::::::::::: ]"

fswatch -0 -xnr -o "${LOCAL_DIR}" | xargs -0 -n1 -I '{}' sshpass -p "${REMOTE_PASS}" rsync -avz --delete --exclude-from="${EXCLUDE_FILE}" -e "ssh" "$LOCAL_DIR" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"

rm "${EXCLUDE_FILE}"
