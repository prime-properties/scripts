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
# TODO: deal with storage so existing storage is not lost with a new deployment
# BEGIN: FUNCTIONS

# Init()
# Define and set globals, get user input and create required directories if needed
# Call first!
Init (){
  set -Eeou pipefail
  [[ $EUID -ne 0 ]] && echo -e "Script must be run as root\nTry: sudo bash stage-deploy.sh" && exit 1
  trap Cleanup 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM
  
  ORIG_DIR="$(pwd)"
  SITE_NAME="test-app"
  BASE_DIR="/opt/laravel/${SITE_NAME}"
  RELEASES_DIR="${BASE_DIR}/releases"
  SITE_SYMLINK="/var/www/prime-properties/${SITE_NAME}/public"
  ARCHIVE_FILE=
  RELEASE_DIR=
  PAT_TOKEN=
  GIT_TAG=
  
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

  # TEMP FOR TESTING
  PAT_TOKEN="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"
  GIT_TAG="deploy1-test"
  
  RELEASE_DIR="${RELEASES_DIR}/${GIT_TAG}"
  ARCHIVE_FILE="${RELEASES_DIR}/site_archive_${GIT_TAG}.tar"

  [[ -d "${RELEASE_DIR}" ]] && 
  echo "A release for ${TAG} seems to already exist. Run: sudo rm -rf ${RELEASE_DIR} and try again." &&
  echo "Script aborted" && exit 1

  [[ -f "${ARCHIVE_FILE}" ]] && 
  echo "${ARCHIVE_FILE} already exists. Run: sudo rm -rf ${ARCHIVE_FILE} and try again." &&
  echo "Script aborted" && exit 1

  mkdir -p "${BASE_DIR}" && 
  mkdir -p "${RELEASES_DIR}" &&
  mkdir -p "${BASE_DIR}/storage"
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

# Set_Symlinks()
# Must be called after Deploy()
Set_Symlinks() {
  # Symbolic link from release to webroot
  ln -sf "${RELEASE_DIR}/public" "${SITE_SYMLINK}" && echo "Symlinked ${RELEASE_DIR}/public TO ${SITE_SYMLINK}"

  # Symbolic link to .env file
  [[ ! -f "${BASE_DIR}/.env" ]] &&
  echo "${BASE_DIR}/.env does not exist so a new .env file will be created there from ${RELEASE_DIR}/.env.example" &&
  echo "You will need to edit ${BASE_DIR}/.env which will be symlinked to ${RELEASE_DIR}/.env" &&
  cp "${RELEASE_DIR}/.env.example" "${BASE_DIR}/.env"
  ln -sf "${BASE_DIR}/.env" "${RELEASE_DIR}/.env" && echo "Symlinked ${BASE_DIR}/.env TO ${RELEASE_DIR}/.env"

  # TODO: Symbolic link to storage
  
}

#Backup_Laravel_Dot_Env() {
#  local src="${SITE_LOC}/.env"
#  local dest="$(dirname "${SITE_LOC}")/.env_${TIMESTAMP}"

#  [[ -f "${src}" ]] || return 0 
#  cp "${src}" "${dest}" && echo "Backed up ${src} to ${dest}"
#}

#Restore_Laravel_Dot_Env() {
#  local src="$(dirname "${SITE_LOC}")/.env_${TIMESTAMP}"
#  local dest="${SITE_LOC}/.env"

#  [[ -f "${src}" ]] || return 0
#  mv "${src}" "${dest}" && echo "Restored ${src} to ${dest}"
#}

Deploy() {
  tar -xf "${ARCHIVE_FILE}" --strip-components=1 --directory="${RELEASE_DIR}" &&
  echo -e "${ARCHIVE_FILE} has been extracted to ${RELEASE_DIR}"
  # TODO: remove and recreate .env symlink
  # TODO: remove and recreate storage symlink
  # TODO: remove and recreate site symlink
}

Cleanup() {
  trap '' 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM
  cd "${ORIG_DIR}"
  #[[ -f "${ARCHIVE_FILE}" ]] && rm "${ARCHIVE_FILE}"

  #[[ -d "${WORKING_DIRECTORY}" && "${WORKING_DIRECTORY}" != "${HOME}" ]] && 
  #rm -rf "${WORKING_DIRECTORY}"

  #[[ -f "${SITE_LOC}/.env_${TIMESTAMP}.." ]] &&
  #rm "${SITE_LOC}/.env_${TIMESTAMP}.."
}

Success_Message() {
  local repo_url="https://github.com/prime-properties/prime-properties-example-stack"
  echo "SUCCESS: tag ${GIT_TAG} from ${repo_url} has been deployed"
}

Main() {
  Init && Download_Archive && Deploy && Success_Message
}
# END: FUNCTIONS

Main