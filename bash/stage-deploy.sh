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

  # Since we use nvm this seems to be required to use node in this shell since 
  # the way this script is invoked (via bash) would bypass ~/.bashrc
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
  
  ORIG_DIR="$(pwd)"
  SITE_NAME="test-app"
  BASE_DIR="/opt/laravel/${SITE_NAME}"
  RELEASES_DIR="${BASE_DIR}/releases"
  SITE_SYMLINK_DIR="/var/www/prime-properties/${SITE_NAME}"
  SITE_SYMLINK="${SITE_SYMLINK_DIR}/public"
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
  #PAT_TOKEN=
  #GIT_TAG=
  
  RELEASE_DIR="${RELEASES_DIR}/${GIT_TAG}"
  ARCHIVE_FILE="${RELEASES_DIR}/site_archive_${GIT_TAG}.tar"

  #[[ -d "${RELEASE_DIR}" ]] && 
  #echo "A release for ${GIT_TAG} seems to already exist. Run: sudo rm -rf ${RELEASE_DIR} and try again." &&
  #echo "Script aborted" && exit 1

  #[[ -f "${ARCHIVE_FILE}" ]] && 
  #echo "${ARCHIVE_FILE} already exists. Run: sudo rm -rf ${ARCHIVE_FILE} and try again." &&
  #echo "Script aborted" && exit 1
  mkdir -p "${SITE_SYMLINK_DIR}" &&
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

  # Fugly file checking
  local check_file="$(file -bL --mime "${ARCHIVE_FILE}" | grep -o 'application/json')"
  [[ $check_file == 'application/json' ]] && 
  echo "Error downloading from GitHub" && cat -v "${ARCHIVE_FILE}" && exit 101
  check_file="$(file -bL --mime "${ARCHIVE_FILE}" | grep -o 'text/plain')"
  [[ $check_file == 'text/plain' ]] && 
  echo "Error downloading from GitHub" && cat -v "${ARCHIVE_FILE}" && echo && exit 101

  echo "Downloaded ${ARCHIVE_FILE} from GitHub"

}

# Set_Symlinks()
# Must be called after Deploy()
Set_Symlinks() {
  # Symbolic link from release to webroot
  ln -sf "${RELEASE_DIR}/public" "${SITE_SYMLINK}" && echo "Symlinked ${RELEASE_DIR}/public TO ${SITE_SYMLINK}"

  # Symbolic link to .env file
  [[ ! -f "${BASE_DIR}/.env" ]] &&
  echo "${BASE_DIR}/.env does not exist so a new .env file will be created there from ${RELEASE_DIR}/.env.example" &&
  echo "Before starting the app, you will need to edit ${BASE_DIR}/.env which will be symlinked to ${RELEASE_DIR}/.env" &&
  cp "${RELEASE_DIR}/.env.example" "${BASE_DIR}/.env"
  ln -sf "${BASE_DIR}/.env" "${RELEASE_DIR}/.env" && echo "Symlinked ${BASE_DIR}/.env TO ${RELEASE_DIR}/.env"

  # TODO: Symbolic link to storage
  
}

Deploy() {
  mkdir -p "${RELEASE_DIR}"
  tar -xf "${ARCHIVE_FILE}" --strip-components=1 --directory="${RELEASE_DIR}" &&
  echo -e "${ARCHIVE_FILE} has been extracted to ${RELEASE_DIR}"
  # TODO chown all files as www for apache
}

Prompt_Start_App() {
  set -o posix # use POSIX mode so SIGINT can be traped when looping a read command
  while true; do
    echo -n "Proceed with starting the Laravel app at ${RELEASE_DIR} [y]/[n]?: "
    read yn || exit
    case $yn in
        [Yy]* ) break;;
        [Nn]* ) exit;;
        * ) echo "Please answer y to proceed or n to cancel";;
    esac
  done
  echo
  set +o posix # return to default mode
}

# nvm makes npm wierd because it was installed as root? Its wonly but it works when sourced and run as root
Start_App() {
  chown -R roadkill_admin:roadkill_admin "${RELEASE_DIR}"
  cd "${RELEASE_DIR}" &&
  sudo -u roadkill_admin composer install -o --no-interaction --no-dev &&
  . ~/.nvm/nvm.sh &&
  npm install &&
  npm run build &&

  # Run optimization commands for laravel
  sudo -u roadkill_admin php artisan optimize &&
  sudo -u roadkill_admin php artisan cache:clear &&
  sudo -u roadkill_admin php artisan route:cache &&
  sudo -u roadkill_admin php artisan view:clear &&
  sudo -u roadkill_admin php artisan config:cache 
}

Msg_Success_Deploy() {
  local repo_url="https://github.com/prime-properties/prime-properties-example-stack"
  echo "SUCCESS: tag ${GIT_TAG} from ${repo_url} has been deployed"
}

# TODO: deal with taking down any running app so we dont have moe than one app running at a time. is this even needed?
Msg_Success_App_Start() {
  echo "SUCCESS: Laravel app is running at ${RELEASE_DIR}"
  echo "Check server configs to make sure it is being served from the Symlink ${SITE_SYMLINK}"
}

Cleanup() {
  trap '' 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM
  cd "${ORIG_DIR}"
  # TODO: remove archive file?
}

Main() {
  Init && 
  Download_Archive && 
  Deploy && 
  Set_Symlinks && 
  Msg_Success_Deploy &&
  Prompt_Start_App &&
  Start_App &&
  Msg_Success_App_Start
}
# END: FUNCTIONS

Main