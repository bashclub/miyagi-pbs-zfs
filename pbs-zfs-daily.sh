#!/bin/bash

#Requirements for Myiagi ultimate Backup found in README! Always use a Config File!

while getopts "c:" arg; do
  case $arg in
    c)
      configfile=$OPTARG
      echo $configfile
      ;;
esac
done

source $configfile

ssh root@$SOURCEHOST zfs set $ZPUSHTAG=subvols $ZFSROOT

echo "target=$ZFSTRGT" > /etc/bashclub/$SOURCEHOST.conf
echo "source=root@$SOURCEHOST" >> /etc/bashclub/$SOURCEHOST.conf
echo "sshport=$SSHPORT" >> /etc/bashclub/$SOURCEHOST.conf
echo "tag=$ZPUSHTAG" >> /etc/bashclub/$SOURCEHOST.conf
echo "snapshot_filter=$ZPUSHFILTER" >> /etc/bashclub/$SOURCEHOST.conf
echo "min_keep=$ZPUSHMINKEEP" >> /etc/bashclub/$SOURCEHOST.conf
echo "zfs_auto_snapshot_keep=$ZPUSHKEEP" >> /etc/bashclub/$SOURCEHOST.conf
echo "zfs_auto_snapshot_label=$ZPUSHLABEL" >> /etc/bashclub/$SOURCEHOST.conf

/usr/bin/bashclub-zsync -d -c /etc/bashclub/$SOURCEHOST.conf

CHECKZFS=$(which checkzfs)

# So one Day has 1440 Minutes, so we go condition Yellow on 1500
$CHECKZFS --source $SOURCEHOST --replicafilter "$ZFSTRGT/" --filter "#$ZFSROOT/|#$ZFSSECOND/" --threshold 1500,2000 --output checkmk --prefix pull-$(hostname):$ZPUSHTAG> /tmp/cmk_tmp.out && ( echo "<<<local>>>" ; cat /tmp/cmk_tmp.out ) > /tmp/90000_checkzfs

scp /tmp/90000_checkzfs $SOURCEHOST:/var/lib/check_mk_agent/spool/90000_checkzfs_$(hostname)_$ZPOOLSRC

if [[ "$BACKUPSERVER" == "no" ]]
then 
echo No Backup configured in this Run
exit
fi

PRUNEJOB=$(ssh $PBSHOST proxmox-backup-manager prune-job list --output-format json-pretty | grep -m 1 "id" | cut -d'"' -f4)


###

   if [ $(date +%u) == $MAINTDAY ]; then 
	echo "MAINTENANCE"

        ssh root@$PBSHOST proxmox-backup-manager prune-job run $PRUNEJOB
    	ssh root@$PBSHOST proxmox-backup-manager garbage-collection start $BACKUPSTOREPBS

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
    if [ $(date +%u) == $MAINTDAY ]; then ssh root@$PBSHOST proxmox-backup-manager verify backup; fi

/etc/cron.daily/zfs-auto-snapshot #protecting all  Datasets/ZVOLs except the Replicas with daily Snaps

#doing updates without regeret


if [[ "$UPDATES" == "yes" ]]
then
	apt dist-upgrade -y
	ssh $PBSHOST apt dist-upgrade -y
 else
 	echo no Updates configured - Consider updating more often!

fi


if [[ "$SHUTDOWN" == "yes" ]]
then
	shutdown now
else 
	echo no Shutdown configured - Next run has to be set in crontab!
fi
