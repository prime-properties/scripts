#!/bin/bash
#
# Copyright © 2023 Prime Properties
# Written by Apolo Pena
#
# dev-get-provisioning.sh
# Description:
# Downloads a release for prime properties provisioning scripts for the remote development server
#
# Notes:
# Requires a Github Personal access token
# Requires a valid tag/release name. See https://github.com/prime-properties/provisioning/releases

# BEGIN: GLOBALS
TIMESTAMP="$(date +%s)"
WORKING_DIRECTORY="${HOME}/tmp_${TIMESTAMP}"
ARCHIVE_FILE="${WORKING_DIRECTORY}/archive_${TIMESTAMP}"
TOKEN= # Github PAT token
TAG=
# END: GLOBALS

# BEGIN: FUNCTIONS
Prompt_User (){
  set -o posix # use POSIX mode so SIGINT can be traped when looping a read command
  echo "This script will download a provisioning release for the prime properties development server."
  echo "You will need a proper GitHub access token and tag/release name"
  echo "For tag/release names see: https://github.com/prime-properties/provisioning/releases"
  echo "The scripts will be downloaded to ~/.provisioning-<tag/release>"
  echo "Where <tag/release> is equal to the valid tag/release name you entered"
  while true; do
    echo -n "GitHub Access token: "
    read -s TOKEN || exit
    case $TOKEN in
        "")echo "This cannot be empty";;
        [Cc]*) exit;;
        * ) if [[ $t =~ '^ *$' ]]; then 
              echo "This cannot be blank"
            else 
              break; 
            fi
        ;;
    esac
  done
  echo
    while true; do
    read -p "Tag/Release name (something like v0.0.1-dev): " TAG || exit
    case $TAG in
        "")echo "This cannot be empty";;
        [Cc]*) exit;;
        * ) if [[ $t =~ '^ *$' ]]; then 
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
# END:  FUNCTIONS

# TODO: change this to use a deploy key since the provisioning repo is from an organization.
# Access should be for just reading the repo. Not full private repo scope for a user.
# It is not very secure to send out the pat token like this
Download_Archive() {
  mkdir -p "${WORKING_DIRECTORY}"
  curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/prime-properties/provisioning/tarball/${TAG}" \
  > "${ARCHIVE_FILE}"
}

Extract_Archive() {
  local dest="${HOME}/.provisioning-${TAG}"
  mkdir -p "${dest}"
  tar -xvf "${ARCHIVE_FILE}" --strip-components=1 --directory="$dest"
  [[ $? -eq 0 ]] &&
  echo -e "\nSUCCESS!. The scripts have been downloaded to ${dest}"
}

Cleanup () {
  trap '' 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM
  [[ -d "${WORKING_DIRECTORY}" && "${WORKING_DIRECTORY}" != "${HOME}" ]] && 
  rm -rf "${WORKING_DIRECTORY}"
}

Main() {
  Prompt_User &&
  Download_Archive &&
  Extract_Archive
}

# Trap all signals that would terminate the program so we can cleanup any mess.
# This trap is removed in the cleanup function so signals are not caught twice.
trap Cleanup 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM

Main
