#!/bin/bash

#
# wrapper script for restic
#

# exit on any error
set -e

# first parameter is the profile/repository
PROFILE="$1"

if [ -z $PROFILE ]; then
	echo "Usage $0 [backup_full_data|backup_full_rare|backup_full_system] <restric parameters>"
	exit 0
fi

# testing with 1=erweiterte Debug-Ausgabe
DEBUG=1

SCRIPT_PATH=$(dirname "$(readlink -e "$0")")
CONFIG=$SCRIPT_PATH/restic.conf

echo "Using profile $PROFILE and config $CONFIG"

# load wrapper config
source $CONFIG

# TSC feature configuration
export RESTIC_KEYSPATH
export RESTIC_FOLLOWSLINK="Y"

# we use rlone instead of internal sftp. rclone performce better than sftp
export RESTIC_REPOSITORY="rclone:cloud:/users/$cloud_user/${backup_target_folder}/$PROFILE"

export RESTIC_PASSWORD_FILE="$RESTIC_KEYSPATH/pw_$PROFILE.txt"
export RESTIC_CACHE_DIR

# remove first parameter (my repository) - now the rest parameters are used by restric
shift

# additional ops for restic if debugging is enabled
adops=""
if [ $DEBUG == "1" ]; then
	adops="-v"
fi

# if backup, add exclude-file
for i in "$@"
do
	if [ $i == "backup" ]; then
		adops="$adops --exclude-file=$RESTIC_KEYSPATH/excludes.txt"
	fi
done

# build the executed cmd
cmd="$SCRIPT_PATH/$restic_binary -o rclone.program='"${rcone_binary}"' $@ $adops"

# some debugging
if [ $DEBUG == "1" ]; then
	echo "WRAPPER-CONFIG:    $CONFIG"
	echo "RESTIC_KEYSPATH:   $RESTIC_KEYSPATH"
	echo "RESTIC_REPOSITORY: $RESTIC_REPOSITORY"
	echo "RESTIC_CACHE_DIR:  $RESTIC_CACHE_DIR"
	echo "RCLONE_CONFIG:     $RCLONE_CONFIG"
	echo "Execute:           $cmd"
fi

# export rclone env from restic.conf
export RCLONE_CONFIG RCLONE_RETRIES RCLONE_RETRIES_SLEEP

# execute cmd
if [ $DEBUG == "1" ]; then
	time $cmd
else
	$cmd
fi

