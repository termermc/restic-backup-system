# restic-backup-system
Backup system using restic and backup scripts.

Backups stored using restic, and backup configs define where to store the backup, where the backup source directory is
Configs are stored in the `configs` directory relative where `backup.sh` is located.

## How To Use
 - Install [restic](https://restic.net/) if you haven't already
 - Clone this repository into any location
 - Run `backup.sh` without any arguments to create required directories see the script's usage instructions

## Configs
To see an example config, view the contents of `example.conf`.
Configs should not contain any scripting other than `export` statements, because they are run for actions other than `start`.

### Pre/Post-Backup Scripts
Configs may have optional pre-backup and post-backup scripts. They should be marked as executable because they are called as normal scripts, not included with `source`.

The config's `tmp` subdirectory path is passed as the first argument.
Note that the directory will be deleted once the backup has fully completed (including execution of all config scripts).

They are only run for the `start` action.

To see an example pre-backup script, view the contents of `example.pre`.
To see an example post-backup script, view the contents of `example.post`.

### Passwords
Repository passwords for configs can be stored in the `passwords` directory. If a file with the config's name exists in `passwords`, it will be used as the password file.

### Config Requirements
 - All configs must end with `.conf`
 - A config must have at least `.conf` file, but pre/post-backup scripts are optional
 - All pre-backup scripts must end with `.pre`
 - All post-backup scripts must end with `.post`

## Restoring
Use the "restore" command as explained by the in-program help.

The only thing to keep in mind is that relative paths passed for the restore path are relative to the directory `backup.sh` is located, not to the current working directory.
