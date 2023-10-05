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
GITHUB_TOKEN="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"
ARCHIVE_NAME="archive_$(date +%s)"
TAG_NAME=
# END: GLOBALS

# BEGIN: FUNCTIONS
Prompt_User (){
  set -o posix # use POSIX mode so SIGINT can be traped when looping a read command
  echo "This script will download a provisioning release for the prime properties development server."
  echo "You will need a proper GitHub access token and the tag/release name"
  echo "For tag/release names see: https://github.com/prime-properties/provisioning/releases"
  echo "The scripts will be downloaded to ~/.provisioning"
  while true; do
    read -p "GitHub Access token: " GITHUB_TOKEN || exit
    case $TAG_NAME in
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
  echo -n
    while true; do
    read -p "Tag/Release name (something like v0.0.1-dev): " TAG_NAME || exit
    case $TAG_NAME in
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
  echo -n
  set +o posix # return to default mode
}
# END:  FUNCTIONS

Download_Archive() {
  curl -L \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GHA_TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://github.com/prime-properties/provisioning/archive/refs/tags/${TAG_NAME}.tar.gz" > "~/${ARCHIVE_NAME}"
}

Untar_Archive() {
  tar -xvf "~/${ARCHIVE_NAME}"
}

Cleanup () {
  trap '' 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM
  # copy ~/${ARCHIVE_NAME} to .provisioning
  # delete ~/${ARCHIVE_NAME} and the folder it extracted
}

Main() {
  echo
}

# Trap all signals that would terminate the program so we can cleanup any mess we made. 
# This trap is removed in the cleanup function so signals are not caught twice.
trap Cleanup 0 1 2 3 13 15 # EXIT HUP SIGINT QUIT PIPE TERM

Main
