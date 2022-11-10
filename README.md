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

The directory where `backup.sh` is located is passed as the first argument.

They are only run for the `start` action.

To see an example pre-backup script, view the contents of `example.pre`.
To see an example post-backup script, view the contents of `example.post`.

### Passwords
Repository passwords for configs can be stored in the 

### Config Requirements
 - All configs must end with `.conf`
 - A config must have at least `.conf` file, but pre/post-backup scripts are optional
 - All pre-backup scripts must end with `.pre`
 - All post-backup scripts must end with `.post`
