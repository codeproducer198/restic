#!/bin/bash

#
# wrapper script for restic
#

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

source $CONFIG

# TSC feature configuration
export RESTIC_KEYSPATH
export RESTIC_FOLLOWSLINK="Y"

# we want to set the SSH-key ID via "-i" and not via ".ssh"-folder, so we cant use the 
#   RESTIC_REPOSITORY="sftp:$cloud_user@sftp.hidrive.strato.com:/users/$cloud_user/restic/backup_full_data"
# set here no user - its set in the ssh_cmd
export RESTIC_REPOSITORY="sftp::/users/$cloud_user/${backup_target_folder}/$PROFILE"
export RESTIC_PASSWORD_FILE="$RESTIC_KEYSPATH/pw_$PROFILE.txt"
export RESTIC_CACHE_DIR

# use SSH with SSH-key file
ssh_cmd="ssh ${cloud_user}@${cloud_url} -i ${cloud_ssh_key} -s sftp"

# remove first parameter (my repository) - now the rest parameters are used by restric
shift

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

if [ $DEBUG == "1" ]; then
	echo "RESTIC_KEYSPATH:   $RESTIC_KEYSPATH"
	echo "RESTIC_REPOSITORY: $RESTIC_REPOSITORY"
	echo "RESTIC_CACHE_DIR:  $RESTIC_CACHE_DIR"
	echo "Execute:           $restic_binary -o sftp.command='"$ssh_cmd"' "$@" $adops"
fi

$SCRIPT_PATH/$restic_binary -o sftp.command="$ssh_cmd" "$@" $adops
