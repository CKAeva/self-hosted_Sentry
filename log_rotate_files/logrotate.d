# Retention behaviour is controlled by `/etc/logrotate.d/application
# run "vi /etc/logrotate.d/application" command and paste below content in it.

/var/log/application.log {
    daily           # Rotate once per day
    rotate 5        # Keep 5 rotated files; the 6th causes the oldest to be deleted
    compress        # Compress rotated files with gzip (.gz)
    delaycompress   # Skip compressing the most recently rotated file (keeps it readable for live log shippers)
    missingok       # Do not error if the log file is absent
    notifempty      # Skip rotation if the log file is empty
    copytruncate    # Copy the active log, then truncate in place — no restart of the writing process required
    create 0640 root root  # Recreate the log file after rotation with these permissions and ownership
}
