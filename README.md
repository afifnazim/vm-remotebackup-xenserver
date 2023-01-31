# vm-remotebackup-xenserver
Automated backup of XenServer VMs are sent to remote NAS drive using this simple script. 

As per our day to day operation, most of the time we think about taking enough backup, so that we can be prepare for any disaster and so that we can recover from our machines from a point. 

By using this script we can easily take backup of the XenServer VMs and send it to remote location or remote NAS drive. 

Please check the ```script.sh``` file for the backup script.

After the ```script.sh``` file is created, we need to install crontab to schedule the VM export on off-peak hours, as we will downtime. 

## Crontab setting: 

```
crontab -e

# Day 1
00 23 1 * * nice -n 19 /bin/sh script.sh day1 2>&1 | mail -s "day 1 vm backups" something@something.com
```

NOTE: THIS BACKUP PROCESS WILL TAKE TIME DEPENDING ON THE VOLUME OF EACH VM AND ALSO IT WILL RESTART THE VMs OF WHICH IT WILL TAKE BACKUP. SO PLEASE REMEMBER TO SAVE YOUR WORK ACCORDINGLY.
