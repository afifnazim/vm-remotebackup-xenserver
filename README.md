# vm-remotebackup-xenserver
Automated backup of XenServer VMs are sent to remote NAS drive using this simple script. 

As per our day to day operation, most of the time we think about taking enough backup, so that we can be prepare for any disaster and so that we can recover from our machines from a point. 

By using this script we can easily take backup of the XenServer VMs and send it to remote location or remote NAS drive. 

Please check the ```script.sh``` file for the backup script.

NOTE: THIS BACKUP PROCESS WILL TAKE TIME DEPENDING ON THE VOLUME OF EACH VM AND ALSO IT WILL RESTART THE VMs OF WHICH IT WILL TAKE BACKUP. SO PLEASE REMEMBER TO SAVE YOUR WORK ACCORDINGLY.
