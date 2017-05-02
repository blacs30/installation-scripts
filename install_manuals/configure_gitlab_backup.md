# Setup Gitlab Backup

### Gitlab Backkup Configuration
I use the omnibus installation of gitlab. See my gitlab installation page for the basic setup incl. external nginx and https configuration.

Following changes in the gitlab.rb were required for a local backup:
`vi /etc/gitlab/gitlab.rb`

comment in and set the value as in the following lines, keep in mind that spaces matter :)  
 - `gitlab_rails['backup_keep_time'] = 604800`  
 This sets the backup keep time to 7 days
 - `gitlab_rails['backup_upload_connection'] = {`  
   Here the bacup section starts, so activate it (remove the # at the beginning)
 - `'provider' => 'local',`  
   Set the provider to local, other remote storages are possible too.
 - `'local_root' => '/tmp/mysqlbackup',`  
   Set the root backup folder, this is a folder where other backup routines grab this backup and copy it to a different location - the tmp should is of course _temporary_
 - `gitlab_rails['backup_upload_remote_directory'] = 'gitlab_backups'`  
   This sets a subfolder for the backup within the root directory.
   Folders will be created if they don't exist.
 - `}`
   Close the section, important not to forget.

The full minimum required block for the backup looks then this way:  
 ```
 gitlab_rails['backup_keep_time'] = 604800
 gitlab_rails['backup_upload_connection'] = {
    'provider' => 'local',
    'local_root' => '/tmp/mysqlbackup',
 }
 gitlab_rails['backup_upload_remote_directory'] = 'gitlab_backups'
 ```

Run the reconfigure command after changing the gitlab.rb file:
  - `gitlab-ctl reconfigure`

### Setup crontab:
This was enough for me to have a backup running every midnight
`(crontab -l 2>/dev/null; echo "0 0 * * * /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1") | crontab -`

### Source
Everything that I needed was written down here:  
https://gitlab.com/gitlab-org/gitlab-ce/blob/master/doc/raketasks/backup_restore.md#configure-cron-to-make-daily-backups
