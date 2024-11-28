#!/bin/bash

echo "Sleeping for one Minute to be interruped if necessary"
sleep 60

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

# bashclub-zsync Part

echo "Configuring and runnging bashclub-zsyncs Config in /etc/bashclub/$SOURCEHOST.conf"

SOURCEHOSTNAME=$(ssh $SOURCEHOST hostname)

ssh root@$SOURCEHOST zfs set $ZPUSHTAG=all $ZFSROOT
ssh root@$SOURCEHOST zfs set $ZPUSHTAG=all $ZFSSECOND
ssh root@$SOURCEHOST zfs set $ZPUSHTAG=all rpool/pveconf #you have to use our postinstaller on source

echo "target=$ZFSTRGT" > /etc/bashclub/$SOURCEHOST.conf
echo "source=root@$SOURCEHOST" >> /etc/bashclub/$SOURCEHOST.conf
echo "sshport=$SSHPORT" >> /etc/bashclub/$SOURCEHOST.conf
echo "tag=$ZPUSHTAG" >> /etc/bashclub/$SOURCEHOST.conf
echo "snapshot_filter=$ZPUSHFILTER" >> /etc/bashclub/$SOURCEHOST.conf
echo "min_keep=$ZPUSHMINKEEP" >> /etc/bashclub/$SOURCEHOST.conf
echo "zfs_auto_snapshot_keep=$ZPUSHKEEP" >> /etc/bashclub/$SOURCEHOST.conf
echo "zfs_auto_snapshot_label=$ZPUSHLABEL" >> /etc/bashclub/$SOURCEHOST.conf

/usr/bin/bashclub-zsync -d -c /etc/bashclub/$SOURCEHOST.conf

# checkzfs Part
CHECKZFS=$(which checkzfs)

# So one Day has 1440 Minutes, so we go condition Yellow on 1500
echo "Running checkzfs via $SOURCEHOSTNAME and this Miyagi Server"
$CHECKZFS --source $SOURCEHOST --replicafilter "$ZFSTRGT/" --filter "#$ZFSROOT/|#$ZFSSECOND/" --threshold 1500,2000 --output checkmk --prefix pull-$(hostname):$ZPUSHTAG> /tmp/cmk_tmp.out && ( echo "<<<local>>>" ; cat /tmp/cmk_tmp.out ) > /tmp/90000_checkzfs

echo "Copying checkzfs Results to $SOURCEHOSTNAME"
scp /tmp/90000_checkzfs $SOURCEHOST:/var/lib/check_mk_agent/spool/90000_checkzfs_$(hostname)_$ZPOOLSRC

# Updating Miyagi Host to latest Proxmox VE (no major Version Upgrades!)
if [[ "$UPDATES" == "yes" ]]
then
	apt update && apt dist-upgrade -y
	apt autopurge
 else
 	echo "No Updates configured - Consider updating more often!"

fi

# Creating and moving Piggyback data to Sourcehost for soon shut down Miyagi Server
if [[ "$SHUTDOWN" == "yes" ]]
then

	echo "Don´t forget to add a Host in CMK named: miyagi-$SOURCEHOSTNAME-$(hostname) without Agent, Piggyback enabled!"
	echo "<<<<miyagi-$SOURCEHOSTNAME-$(hostname)>>>>" > 90000_miyagi-$SOURCEHOSTNAME-$(hostname)
	/usr/bin/check_mk_agent >> 90000_miyagi-$SOURCEHOSTNAME-$(hostname)
	echo "<<<<>>>>" >> 90000_miyagi-$SOURCEHOSTNAME-$(hostname)
	scp  ./90000_miyagi-$SOURCEHOSTNAME-$(hostname)  $SOURCEHOST:/var/lib/check_mk_agent/spool
	
 else
	echo "No Shutdown configured, so we don´t do any Piggyback Data"
fi


if [[ "$BACKUPSERVER" == "no" ]]; then 
      echo No Backup configured in this Run
      [[ "$SHUTDOWN" == "yes" ]] && shutdown
fi


if [[ "$BACKUPSERVER" == "no" ]]; then
      echo No Backup configured in this Run
      [[ "$SHUTDOWN" == "yes" ]] && exit
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
	ssh $PBSHOST 	apt update && apt dist-upgrade -y
 else
 	echo no Updates configured - Consider updating more often!

fi


if [[ "$SHUTDOWN" == "yes" ]]
then
	shutdown now
else 
	echo no Shutdown configured - Next run has to be set in crontab!
fi
