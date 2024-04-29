# miyagi-pbs-zfs
Secure Proxmox PVE with Proxmox Backup Server PBS and ZFS Pull Replication with a mostly turned off System
Optimize Processes without colliding Replications, Backups, Monitorings or Scrubs
Save lot of Money with less performant Hardware

What it does
Miyagi said, best defense, no be there

Usecase
Proxmox Backupserver is running unnecessarly 24/7
ZFS Replication is usually done by a zfs send, so its a push

What if our Backup/Replicaserver is turned off most the time, nobody can attack it

Consider not using a Gateway, use Routes!

Prerequisites

Proxmox with ZFS on Host to Backup/Replicate -  we recommend check_mk Agent for automaticly added Tests
Proxmox with ZFS on Target Machine - it´s WOL MAC Address
Proxmox Backup Server as a VM oder better PCT on Target machine
Your contet of your Public Key of the Target Host .ssh/id_rsa.pub added to
  Host to Backup .ssh/authorized_keys
  Proxmox Backup Server on Target Host .ssh/authorized_keys
ssh one from your Target Host to Source Host and PBS to confirm Host Key with a yes

At all Proxmox 'apt install zfs-auto-snapshot -y'
Target Hosts needs the following tools to be installed

  https://github.com/bashclub/zsync
  https://github.com/bashclub/check-zfs-replication

Any Host waking up the Target Host or a daily Cronjob

What we do...

Turning on the Computer with a @reboot Cron

@reboot /root/pbs-zfs-daily.sh -c 200-ssd.conf && /root/pbs-zfs-daily.sh -c 200-hdd.conf

So Miyagi at this point can pull two ZFS-Datastores to one Target Datastore, using the full Path of ZFS for Naming.
If you have multiple Target Datasets, please run multiple Configs and disable Proxmox Backup Server!
Miyagi will tag your Source for Replication with Zsync!

Replicating by a Pull with https://github.com/bashclub-zsync
Pushing a Report to Proxmox Source Host, monitored by Check_MK unsing https://github.com/bashclub/checkzfs
The Report will be found by Check_MK´s built in Autdiscovery for new Services.
Data will be valid vor about one Day (90000s) bevore it expires.
So there nothing can go wrong!

Regarding to the Weekday doing Maintenance on Proxmox Backup Server for getting more free Space.
Triggering a Push Backup with PBS (only Way to do) Backup to PBS and checking Exitcode for Report
Reporting PBS Result with 100% certainty in compact OK/WARN State to backuped PVE Host using Check_MK

Verifying older Backups
Protecting the PBS Backups with a ZFS Snapshot
Updating the Host and PBS

TURNING OFF THE MACHINE!!!
Test Targets Tank if less than 75% free, otherwise report to Check_MK
Test Disks after PBS Maintenance, before shutdown with SmartCTL Short Test and report to Check_MK
Support multiple Sources
