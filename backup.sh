#!/usr/bin/env bash

# Check dependencies
if [ ! -n "$( which restic )" ]; then
	echo "Could not find restic."
	echo "It is either not installed, or not present in PATH."
	exit 1
fi

ACTION="$1"
CONFIG_NAME="$2"
CONFIG_NAME_SANITIZED="$( echo $CONFIG_NAME | sed 's/\///g' )"
SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

CONFIGS_DIR="$SCRIPT_PATH/configs"
PASSWORDS_DIR="$SCRIPT_PATH/passwords"
CONFIG_BASE_PATH="$CONFIGS_DIR/$CONFIG_NAME_SANITIZED"
CONFIG_PATH="$CONFIG_BASE_PATH.conf"
CONFIG_PRE_SCRIPT_PATH="$CONFIG_BASE_PATH.pre"
CONFIG_POST_SCRIPT_PATH="$CONFIG_BASE_PATH.post"
CONFIG_PASSWORD_PATH="$PASSWORDS_DIR/$CONFIG_NAME_SANITIZED"

# Make sure script dir is the working dir
cd "$SCRIPT_PATH"

# Create required dirs if they don't already exist
mkdir -p "$CONFIGS_DIR"
mkdir -p "$SCRIPTS_DIR"

# Check dir permissions and warn if they are group or world-readable
function check_dir_perms () {
	local non_user_perms=$( ls -la "$1" | tail -n 1 | sed 's![rwxd-]\{4\}\([rwx-]\{6\}\).*!\1!' )
	if [ $non_user_perms != '------' ]; then
		echo "WARNING: Directory \"$1\" can be read by users other than the owner!"
	fi
}
check_dir_perms "$CONFIGS_DIR"
check_dir_perms "$SCRIPTS_DIR"

# Check for params
if [ "$ACTION" = 'help' ] || [ ! -n "$ACTION" ] || [ ! -n "$CONFIG_NAME" ]; then
	echo "Usage: $0 <help|init|start|restore> <config name>"
	exit 1
fi

# Check if config exists
if [ ! -f "$CONFIG_PATH" ]; then
	echo "No such config \"$CONFIG_NAME\""
	exit 1
fi

# Load config
source "$CONFIG_PATH"

RESTIC_CMD="$( which restic )"

# Perform action
if [ "$ACTION" == 'init' ]; then
	echo "Initializing backup repository for config \"$CONFIG_NAME\"..."
	
	$RESTIC_CMD init
elif [ "$ACTION" == 'start' ]; then
	echo "Initiating backup using config \"$CONFIG_NAME\"..."

	# Run "pre" script if present
	if [ -f "$CONFIG_PRE_SCRIPT_PATH" ]; then
		echo "Running pre-backup script..."
		"$CONFIG_PRE_SCRIPT_PATH" "$SCRIPT_PATH"
	fi

	# Check if backup path exists
	if [ ! -d "$BACKUP_PATH" ]; then
		echo "Path \"$BACKUP_PATH\" specified in config \"$CONFIG_NAME\" does not exist or is not a directory"
		exit 1
	fi
	
	# Use password file if present
	if [ -f "$CONFIG_PASSWORD_PATH" ]; then
		echo "Using password file located at \"$CONFIG_PASSWORD_PATH\""
		export RESTIC_PASSWORD_FILE="$CONFIG_PASSWORD_PATH"
	fi

	# Perform backup
	echo "Starting backup..."
	$RESTIC_CMD backup "$BACKUP_PATH"

	# Run post-backup script if present
	if [ -f "$CONFIG_POST_SCRIPT_PATH" ]; then
		echo "Config post-backup script exists, running it..."
		"$CONFIG_POST_SCRIPT_PATH" "$SCRIPT_PATH"
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
	echo "Unknown action \"$ACTION\". Use \"help\" to see available actions and usage."
	exit 1
fi
