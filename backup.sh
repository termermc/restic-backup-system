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
LOGS_DIR="$SCRIPT_PATH/logs"
CONFIG_BASE_PATH="$CONFIGS_DIR/$CONFIG_NAME_SANITIZED"
CONFIG_PATH="$CONFIG_BASE_PATH.conf"
CONFIG_PRE_SCRIPT_PATH="$CONFIG_BASE_PATH.pre"
CONFIG_POST_SCRIPT_PATH="$CONFIG_BASE_PATH.post"
CONFIG_PASSWORD_PATH="$PASSWORDS_DIR/$CONFIG_NAME_SANITIZED"
CONFIG_LOG_PATH="$LOGS_DIR/$CONFIG_NAME_SANITIZED.log"

# Make sure script dir is the working dir
cd "$SCRIPT_PATH"

# Writes a message to the log file without echoing it
function log_write () {
	echo "$1" >> "$( date ) | $CONFIG_LOG_PATH"
}

# Echoes a message and writes it to the log file
function log_echo () {
	echo "$1"
	log_write "$1"
}

# Create required dirs if they don't already exist
function mkdir_with_chmod () {
	if [ ! -d "$1" ]; then
		mkdir -p "$1"
		chmod 700 "$1"
	fi
}

mkdir_with_chmod "$CONFIGS_DIR"
mkdir_with_chmod "$PASSWORDS_DIR"
mkdir_with_chmod "$LOGS_DIR"

# Create log file if it doesn't exist
touch "$CONFIG_LOG_PATH"

# Check dir permissions and warn if they are group or world-readable
function check_dir_perms () {
	local non_user_perms=$( ls -la "$1" | sed -n '2p' | sed 's![rwxd-]\{4\}\([rwx-]\{6\}\).*!\1!' )
	if [ $non_user_perms != '------' ]; then
		echo "WARNING: Directory \"$1\" can be read by users other than the owner! (should be set to 700)"
	fi
}
check_dir_perms "$CONFIGS_DIR"
check_dir_perms "$PASSWORDS_DIR"
check_dir_perms "$LOGS_DIR"

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

# Use password file if present
if [ -f "$CONFIG_PASSWORD_PATH" ]; then
	echo "Using password file located at \"$CONFIG_PASSWORD_PATH\""
	export RESTIC_PASSWORD_FILE="$CONFIG_PASSWORD_PATH"
fi

RESTIC_CMD="$( which restic ) $BACKUP_ADDITIONAL_ARGS"

# Perform action
if [ "$ACTION" == 'init' ]; then
	log_echo "Initializing backup repository for config \"$CONFIG_NAME\"..."
	
	$RESTIC_CMD init
elif [ "$ACTION" == 'start' ]; then
	log_echo "Initiating backup using config \"$CONFIG_NAME\"..."

	# Run "pre" script if present
	if [ -f "$CONFIG_PRE_SCRIPT_PATH" ]; then
		log_echo "Running pre-backup script..."
		"$CONFIG_PRE_SCRIPT_PATH" "$SCRIPT_PATH"
	fi

	# Check if backup path exists
	if [ ! -d "$BACKUP_PATH" ]; then
		log_echo "Path \"$BACKUP_PATH\" specified in config \"$CONFIG_NAME\" does not exist or is not a directory"
		exit 1
	fi

	# Perform backup
	log_echo "Starting backup..."
	$RESTIC_CMD backup "$BACKUP_PATH" $BACKUP_TRAILING_ARGS

	# Run post-backup script if present
	if [ -f "$CONFIG_POST_SCRIPT_PATH" ]; then
		log_echo "Config post-backup script exists, running it..."
		"$CONFIG_POST_SCRIPT_PATH" "$SCRIPT_PATH"
	fi
	
	# Enforce forget policy if present
	if [ -n "$BACKUP_FORGET_POLICIES" ]; then
		log_echo "Enforcing \"$BACKUP_FORGET_POLICIES\" forget policies..."
		$RESTIC_CMD forget $BACKUP_FORGET_POLICIES
	fi

	log_echo "Backup complete"
elif [ "$ACTION" == 'restore' ]; then
	# Strip trailing slash from path
	RESTORE_PATH="$( echo $3 | sed 's/\/$//' )"

	# Check if restore path exists
	if [ ! -n "$RESTORE_PATH" ]; then
		echo "Usage: $0 restore <config name> <restore path>"
		exit 1
	fi
	if [ ! -d "$RESTORE_PATH" ]; then
		log_echo "Restore path \"$RESTORE_PATH\" does not exist or is not a directory"
		exit 1
	fi

	log_echo "Restoring backup for config \"$CONFIG_NAME\" to path \"$RESTORE_PATH\"..."
	$RESTIC_CMD restore latest --target "$RESTORE_PATH"
else
	echo "Unknown action \"$ACTION\". Use \"help\" to see available actions and usage."
	exit 1
fi
