#!/bin/bash
#
# Copyright © 2023 Prime Properties
# Written by Apolo Pena
#
# dev-get-provisioning.sh
# Description:
# Quick and dirty deployment, not for production use
#
# Notes:
# Requires a github PAT, repo tag
#


# BEGIN: INITIALIZATION CODE, set traps, define and set globals, etc
set -Eeou pipefail
trap Cleanup 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM
SITE_NAME="test-app"
SITE_DIR="/opt/laravel/${SITE_NAME}"
SITE_SYMLINK="/var/www/prime-properties/${SITE_NAME}"
#TIMESTAMP="$(date +%s)"
ARCHIVE_FILE="${SITE_DIR}/site_archive_${TIMESTAMP}"
PAT_TOKEN=
GIT_TAG=
# END: INITIALIZATION CODE

# BEGIN: FUNCTIONS
Prompt_User (){
  set -o posix # use POSIX mode so SIGINT can be traped when looping a read command
  while true; do
    echo -n "GitHub Access token: "
    read -s PAT_TOKEN || exit
    case $PAT_TOKEN in
        "")echo "This cannot be empty";;
        [Cc]*) exit;;
        * ) if [[ $PAT_TOKEN =~ '^ *$' ]]; then 
              echo "This cannot be blank"
            else 
              break; 
            fi
        ;;
    esac
  done
  echo
    while true; do
    read -p "Tag/Release name: " GIT_TAG || exit
    case $GIT_TAG in
        "")echo "This cannot be empty";;
        [Cc]*) exit;;
        * ) if [[ $GIT_TAG =~ '^ *$' ]]; then 
              echo "This cannot be blank"
            else 
              break; 
            fi
        ;;
    esac
  done
  echo
  set +o posix # return to default mode
}

# TODO: change this to use a deploy key since the provisioning repo is from an organization.
# Access should be for just reading the repo. Not full private repo scope for a user.
# It is not very secure to send out the pat token like this
Download_Archive() {
  curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${PAT_TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/prime-properties/prime-properties-example-stack/tarball/${GIT_TAG}" \
  > "${ARCHIVE_FILE}"
}

Backup_Laravel_Dot_Env() {
  local src="${SITE_LOC}/.env"
  local dest="$(dirname "${SITE_LOC}")/.env_${TIMESTAMP}"

  [[ -f "${src}" ]] || return 0 
  cp "${src}" "${dest}" && echo "Backed up ${src} to ${dest}"
}

Restore_Laravel_Dot_Env() {
  local src="$(dirname "${SITE_LOC}")/.env_${TIMESTAMP}"
  local dest="${SITE_LOC}/.env"

  [[ -f "${src}" ]] || return 0
  mv "${src}" "${dest}" && echo "Restored ${src} to ${dest}"
}

Deploy() {
  SITE_DIR="${SITE_DIR}/${GIT_TAG}"
  ARCHIVE_FILE="${SITE_DIR}/site_archive_${GIT_TAG}"
  mkdir -p "${SITE_LOC}" 
  tar -xvf "${ARCHIVE_FILE}" --strip-components=1 --directory="${SITE_DIR}" &&
  echo -e "The site archive has been extracted and moved to ${SITE_DIR}"
  # TODO: remove and recreate .env symlink
  # TODO: remove and recreate storage symlink
  # TODO: remove and recreate site symlink
}

Cleanup() {
  trap '' 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM

  #[[ -d "${WORKING_DIRECTORY}" && "${WORKING_DIRECTORY}" != "${HOME}" ]] && 
  #rm -rf "${WORKING_DIRECTORY}"

  #[[ -f "${SITE_LOC}/.env_${TIMESTAMP}.." ]] &&
  #rm "${SITE_LOC}/.env_${TIMESTAMP}.."
}

Main() {
  Prompt_User
  Download_Archive
  #Backup_Laravel_Dot_Env
  Deploy
  #Restore_Laravel_Dot_Env
}
# BEGIN: FUNCTIONS

Main
# Show Success if we make it this far
repo_url="https://github.com/prime-properties/prime-properties-example-stack"
echo "SUCCESS"
echo "Tag ${GIT_TAG} of the repo ${repo_url} has been deployed to ${SITE_LOC}"