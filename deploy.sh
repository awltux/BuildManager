#!/bin/sh
############################################################################################
# OSGi is a very interesting technology that manages jar file versions 
# and allows for live/faster updates. Especially useful for Web Services.
############################################################################################

PROGNAME=$(basename $0)

function error_exit
{
	echo "$PROGNAME: ${1:-"Unknown Error"}" 1>&2
	exit 1
}

if [ -z $1 ] 
then
	error_exit "Missing command line parameter: Version string e.g. 2.12.0"
fi

if [ -z $APP_DIR ] 
then
	error_exit "Environment variable is not set: APP_DIR"
else
	if [ ! -d $APP_DIR ]
	then
		error_exit "Missing directory: APP_DIR"
	fi
fi
command -v scp >/dev/null 2>&1 || error_exit "Command not on path: scp"
command -v unzip >/dev/null 2>&1 || error_exit "Command not on path: unzip"
command -v zip >/dev/null 2>&1 || error_exit "Command not on path: zip"

START_SERVER_SCRIPT='server-start.sh'
command -v $START_SERVER_SCRIPT >/dev/null 2>&1 || error_exit "Command not on path: $START_SERVER_SCRIPT"

STOP_SERVER_SCRIPT='server-stop.sh'
command -v $STOP_SERVER_SCRIPT >/dev/null 2>&1 || error_exit "Command not on path: $STOP_SERVER_SCRIPT"

ARCHIVE_VERSION="$1"
ARCHIVE_EXTENSION='war'
ARCHIVE_NAME='WebARchive'
ARCHIVE_FILENAME="$ARCHIVE_NAME-$1.$ARCHIVE_EXTENSION"

##############################################################################################
# FOR TESTING: connect back to local machine to emulate a remote copy
##############################################################################################
REMOTE_LOGIN=${REMOTE_LOGIN:-$USER}
REMOTE_HOSTNAME=${REMOTE_HOSTNAME:-'localhost'}
REMOTE_PATH=${REMOTE_PATH:-"/media/sf_vbox_share/remoteFolder/$ARCHIVE_FILENAME"}

WORKING_DIR=${WORKING_DIR:-"$PWD/wip"}
EXTRACT_DIR=${EXTRACT_DIR:-"$WORKING_DIR/extract"}
BACKUP_DIR=${BACKUP_DIR:-"$PWD/backup"}

echo "Clean working directory: $WORKING_DIR"
rm -rf $WORKING_DIR || error_exit "Error while trying to remove dir: $WORKING_DIR"

mkdir -p $EXTRACT_DIR || error_exit "Error while trying to create dir: $EXTRACT_DIR"
mkdir -p $BACKUP_DIR || error_exit "Error while trying to create dir: $BACKUP_DIR"

##############################################################################################
# NOTE: The $REMOTE_LOGIN should be set-up to use keys as 
# this currently prompts for a password; no good for automation :-)
##############################################################################################
echo '##### Copy the remote release file to local working Dir'
scp ${REMOTE_LOGIN}@${REMOTE_HOSTNAME}:${REMOTE_PATH} ${WORKING_DIR} || error_exit "Failed to copy remote file from: $REMOTE_HOSTNAME"

##############################################################################################
# NOTE: Instructions werent clear whether build artifacts were delivered 
# inside a further zip file, so assuming that we are unzipping the WAR file.
##############################################################################################
echo '##### unzip build artifact to working dir'
unzip -q ${WORKING_DIR}/$ARCHIVE_FILENAME -d ${EXTRACT_DIR} || error_exit "Failed to unzip build artifact: ${WORKING_DIR}/$ARCHIVE_FILENAME"

##############################################################################################
# Back up previous deploy; but only if it exists!
##############################################################################################
echo '##### Make backup of existing deploy'
if [ -d $APP_DIR ] 
then
	# use pushd/popd to exclude top level directory in zip file.
	pushd $APP_DIR > /dev/null
	zip -rq $BACKUP_DIR/$ARCHIVE_NAME-`date +%Y%m%d-%H%m%S`.$ARCHIVE_EXTENSION .  || error_exit "Failed to create backup"
	popd > /dev/null
else
	echo "#####    BACKUP SKIPPED! Deploy dir not found: $APP_DIR"
fi

echo '##### STOPPING web server'
$STOP_SERVER_SCRIPT || error_exit "Error while trying to STOP the web server"

echo '##### Remove the existing deployed files'
rm -rf $APP_DIR/* || error_exit "Error while trying to clean the deploy dir: $APP_DIR"

echo '##### Deploy requested build artifact to web server'
cp -rf $EXTRACT_DIR/* $APP_DIR || error_exit "Error while trying to copy to the deploy dir: $APP_DIR"

echo '##### STARTING web server'
$START_SERVER_SCRIPT  || error_exit "Error while trying to START the web server"

echo '##### UPDATE COMPLETE!'


