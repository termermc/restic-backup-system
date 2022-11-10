#!/usr/bin/env bash

# Check dependencies
if [ ! -n "$( which restic )" ]; then
	echo "Could not find restic."
	echo "It is either not installed, or not present in PATH."
	exit 1
fi

ACTION="$1"
CONFIG_NAME="$2"
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Remove slashes from config name to avoid possible arbitrary script execution
CONFIG_BASE_PATH="$SCRIPT_PATH/configs/$( echo $CONFIG_NAME | sed 's/\///g' )"
CONFIG_PATH="$CONFIG_BASE_PATH.conf"
CONFIG_PRE_SCRIPT_PATH="$CONFIG_BASE_PATH.pre"
CONFIG_POST_SCRIPT_PATH="$CONFIG_BASE_PATH.post"

# Check for params
if [ ! -n "$ACTION" ] || [ ! -n "$CONFIG_NAME" ]; then
	echo "Usage: $0 <init|start|restore> <config name>"
	exit 1
fi

# Make sure script dir is the working dir
cd "$SCRIPT_PATH"

# Check if configs dir exists
if [ ! -d './configs' ]; then
	echo 'The "configs" directory does not exist.'
	echo 'There must be a "configs" directory present and config files inside of it to use this tool.'
	exit 1
fi

# Check if config exists
if [ ! -f "$CONFIG_PATH" ]; then
	echo "No such config \"$CONFIG_NAME\""
	exit 1
fi

# Load config
source "$CONFIG_PATH"

# Check backup type
if [ "$BACKUP_TYPE" != 's3' ]; then
	echo "Backup type specified in config is \"$BACKUP_TYPE\", which is not supported."
	echo "Supported backup types: s3"
	exit 1;
fi

RESTIC_CMD="restic -r s3:$S3_DOMAIN/$BUCKET_NAME$BUCKET_PREFIX "

# Perform action
if [ "$ACTION" == 'init' ]; then
	echo "Initializing backup repository for config \"$CONFIG_NAME\"..."
	
	$RESTIC_CMD init
elif [ "$ACTION" == 'start' ]; then
	echo "Initiating backup using config \"$CONFIG_NAME\"..."

	# Run "pre" script if present
	if [ -f "$CONFIG_PRE_SCRIPT_PATH" ]; then
		echo "Running pre-backup script..."
		"$CONFIG_PRE_SCRIPT_PATH"
	fi

	# Check if backup path exists
	if [ ! -d "$BACKUP_PATH" ]; then
		echo "Path \"$BACKUP_PATH\" specified in config \"$CONFIG_NAME\" does not exist or is not a directory"
		exit 1
	fi

	# Perform backup
	$RESTIC_CMD backup "$BACKUP_PATH"

	# Run post-backup script if present
	if [ -f "$CONFIG_POST_SCRIPT_PATH" ]; then
		echo "Config post-backup script exists, running it..."
		"$CONFIG_POST_SCRIPT_PATH"
	fi

	echo "Backup complete"
elif [ "$ACTION" == 'restore' ]; then
	# Strip trailing slash from path
	RESTORE_PATH="$( echo $3 | sed 's/\/$//' )"

	# Check if restore path exists
	if [ ! -n "$RESTORE_PATH" ]; then
		echo "Usage: $0 restore <config name> <restore path>"
		exit 1
	fi
	if [ ! -d "$RESTORE_PATH" ]; then
		echo "Restore path \"$RESTORE_PATH\" does not exist or is not a directory"
		exit 1
	fi

	echo "Restoring backup for config \"$CONFIG_NAME\" to path \"$RESTORE_PATH\"..."
	$RESTIC_CMD restore latest --target "$RESTORE_PATH"
else
	echo "Unknown action \"$ACTION\""
	exit 1
fi
