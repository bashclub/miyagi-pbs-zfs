#!/bin/bash

#Requirements for Myiagi ultimate Backup
## Proxmox Source Host with only daily Autosnapshots, Proxmox Destination Host, Destination Public SSH Key on Source authorized-keys File, autostarting Proxmox Backupserver running on this PVE, zfs set com.sun:auto-snapshots=false on $ZFSTRGT, instaled checkzfs from https://github.com/bashclub/check-zfs-replication, check_mk Agent running on PVE

SOURCEHOST='192.168.50.200' # IP from Proxmox VE System to be backuped and replicated daily
SOURCEHOSTNAME='pve3' #Hostname of Proxmox VE System to be backuped and replicated daily

ZFSROOT='rpool/data' #First Dataset/Datastoresourcepath from Proxmox VE System to be backuped and replicated daily
ZFSSECOND='rpool-hdd/data' #Optional second Dataset
ZFSTRGT='rpool-ssd1/200' #This pulling Machines Target ZFS Sourcepath
ZPOOLSRC=rpool #First Pool/Tank from Proxmox VE System to be backuped and replicated daily
ZPOOLDST=rpool #This pulling Machines Pool/Tank
ZPUSHTAG=bashclub:zsync
ZPUSHMINKEEP=3
ZPUSHKEEP=14
ZPUSHLABEL=zsync-rz
ZPUSHFILTER="\"rz_pull|monthly|daily\"" #zpushlabel kommt automatisch mit

PBSHOST='192.168.50.199' #IP from your Proxmox Backupserver
BACKUPSTORE=backup #Datastorename configured in your  Proxmox VE System to be backuped and replicated daily
BACKUPSTOREPBS=backup #Datastorename configured in your Proxmox Backup Server 
BACKUPEXCLUDE='124,3021,3022,3023,3251,3252,3253,3254' #Machines to be excluded from Proxmox Backup
PRUNEJOB=$(ssh $PBSHOST proxmox-backup-manager prune-job list --output-format json-pretty | grep -m 1 "id" | cut -d'"' -f4)

SSHPORT='22' #SSH Port, usually default 22 internally

MAINTDAY=0

# ssh root@$SOURCEHOST zfs set $ZPUSHTAG=subvols $ZFSROOT
# Schleife für Excludes
echo "target=$ZFSTRGT" > /etc/bashclub/$SOURCEHOST.conf
echo "source=root@$SOURCEHOST" >> /etc/bashclub/$SOURCEHOST.conf
echo "sshport=$SSHPORT" >> /etc/bashclub/$SOURCEHOST.conf
echo "tag=$ZPUSHTAG" >> /etc/bashclub/$SOURCEHOST.conf
echo "snapshot_filter=$ZPUSHFILTER" >> /etc/bashclub/$SOURCEHOST.conf
echo "min_keep=$ZPUSHMINKEEP" >> /etc/bashclub/$SOURCEHOST.conf
echo "zfs_auto_snapshot_keep=$ZPUSHKEEP" >> /etc/bashclub/$SOURCEHOST.conf
echo "zfs_auto_snapshot_label=$ZPUSHLABEL" >> /etc/bashclub/$SOURCEHOST.conf

echo /usr/bin/bashclub-zsync -d -c /etc/bashclub/$SOURCEHOST.conf

# So one Day has 1440 Minutes, so we go condition Yellow on 1500
/usr/local/bin/checkzfs --source $SOURCEHOST --replicafilter "$ZFSTRGT/" --filter "#$ZFSROOT/|#$ZFSSECOND/" --threshold 1500,2000 --output checkmk --prefix pull-$(hostname)> /tmp/cmk_tmp.out && ( echo "<<<local>>>" ; cat /tmp/cmk_tmp.out ) > /tmp/90000_checkzfs

scp /tmp/90000_checkzfs $SOURCEHOST:/var/lib/check_mk_agent/spool

###
exit

   if [ $(date +%u) == $MAINTDAY ]; then 
	echo "MAINTENANCE"

    	ssh root@$PBSHOST proxmox-backup-manager garbage-collection start $BACKUPSTOREPBS
    	ssh root@$PBSHOST proxmox-backup-manager prune-job run $PRUNEJOB
	#optional delete all zfs-auto-snapshots   
 	ssh root@$PBSHOST proxmox-backup-manager verify backup

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

scp  /tmp/90000_checkpbs  root@$SOURCEHOST:/var/lib/check_mk_agent/spool

###

    ssh root@$SOURCEHOST pvesm set $BACKUPSTORE --disable 1

/etc/cron.daily/zfs-auto-snapshot #protecting all  Datasets/ZVOLs except the Replicas with daily Snaps

#doing updates without regeret


#/root/02pull32nas ##PVE32 NAS Replika mit Report auf pve32

apt dist-upgrade -y

#shutdown now
