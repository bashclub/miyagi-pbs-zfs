#!/bin/sh

#Requirements for Myiagi ultimate Backup
## Proxmox Source Host, Proxmox Destination Host, Destination Public SSH Key on Source authorized-keys File, autostarting Proxmox Backupserver running on this PVE, zfs set com.sun:auto-snapshots=false on $ZFSTRGT, instaled checkzfs from https://github.com/bashclub/check-zfs-replication, check_mk Agent running on PVE

SOURCEHOST='192.168.0.241' # IP from Proxmox VE System to be backuped and replicated daily
SOURCEHOSTNAME='PVE' #Hostname of Proxmox VE System to be backuped and replicated daily
ZFSKEEP='10' # How many Snapshots to be kept, suggested 10 Days

ZFSROOT='rpool/data' #First Dataset/Datastoresourcepath from Proxmox VE System to be backuped and replicated daily
ZFSTRGT='rpool/repl' #This pulling Machines Target ZFS Sourcepath
ZPOOLSRC=rpool #First Pool/Tank from Proxmox VE System to be backuped and replicated daily
ZPOOLDST=rpool #This pulling Machines Pool/Tank


PBSHOST='192.168.0.171' #IP from your Proxmox Backupserver
BACKUPSTORE=backup #Datastorename configured in your  Proxmox VE System to be backuped and replicated daily
BACKUPEXCLUDE='103,104,109,110' #Machines to be excluded from Proxmox Backup

SSHPORT='22' #SSH Port, usually default 22 internally
SCRIPTPATH=/usr/bin #Location of bashclub-zfs Tool - https://raw.githubusercontent.com/bashclub/bashclub-zfs-push-pull/master/bashclub-zfs


MAINTDAY=7

SOURCEALL=$(ssh -p$SSHPORT root@$SOURCEHOST 'for src in $(zfs list -H -o name |grep '"$ZFSROOT"'/|grep -v alt|grep -v state|grep -v disk-9); do echo ${src##*/}; done') #determines Source Datasets without 'alt, state and disk-9' in Name - Those are typlically not replicated
echo ''
echo Pulling Replicas from $SOURCEHOST following Datasets/ZVOLS $SOURCEALL
echo ''
for DATA in $SOURCEALL
do
	$SCRIPTPATH/bashclub-zfs -I -R -p $SSHPORT -k $ZFSKEEP -v $SOURCEHOST:$ZFSROOT/$DATA $ZFSTRGT #for debugging add an echo at the Beginning of this line
done
###

# So one Day has 1440 Minutes, so we go condition Yellow on 1500
/usr/local/bin/checkzfs --source $SOURCEHOST --replicafilter $ZFSTRGT/ --filter $ZFSROOT/ --threshold 1500,2000 --output checkmk --prefix pullrepl > /tmp/cmk_tmp.out && ( echo "<<<local>>>" ; cat /tmp/cmk_tmp.out ) > /tmp/90000_checkzfs

scp /tmp/90000_checkzfs $SOURCEHOST:/var/lib/check_mk_agent/spool


###

if [ "$DOW" == $MAINTDAY ]; then
    echo "MAINTENANCE"

    #ssh root@PBSHOST proxmox-backup-manager garbage-collection start (wrong command)
    

else
    echo "Today no Maintenance"
fi


    ssh root@$SOURCEHOST zpool scrub -s $ZPOOLSRC
    zpool scrub -s $ZPOOLDST

    ssh root@$SOURCEHOST pvesm set $BACKUPSTORE --disable 0

### one Day is 86400 Seconds, so we going Condition grey if no new Status File will be pushed

ssh root@$SOURCEHOST vzdump --node $SOURCEHOSTNAME --storage $BACKUPSTORE --exclude  $BACKUPEXCLUDE --mode snapshot --all 1 --notes-template '{{guestname}}' 

if [ $? -eq 0 ]; then
    echo command returned 0 is good
    echo 0 "DailyPBS" - Daily Backup  > /tmp/cmk_tmp.out && ( echo "<<<local>>>" ; cat /tmp/cmk_tmp.out ) > /tmp/90000_checkpbs
else
    echo command returned other not good
    echo 2 "DailyPBS" - Daily Backup  > /tmp/cmk_tmp.out && ( echo "<<<local>>>" ; cat /tmp/cmk_tmp.out ) > /tmp/90000_checkpbs

fi

scp  /tmp/90000_checkpbs  root@SOURCEHOST:/var/lib/check_mk_agent/spool


###

    ssh root@$PBSHOST proxmox-backup-manager verify backup
    ssh root@$SOURCEHOST pvesm set backup --disable 1

#shutdown now
