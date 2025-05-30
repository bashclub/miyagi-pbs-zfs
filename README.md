# miyagi-pbs-zfs
Secure Proxmox PVE with Proxmox Backup Server PBS and ZFS Pull Replication with a mostly turned off System
Optimize Processes without colliding Replications, Backups, Monitorings or Scrubs
Save lot of Money with less performant Hardware

Start it with bash miyagi-pbs-zfs -c configfile

There are german payed Lessons here:
14. + 16.05.2024 (13-17h) - Replikationen und Backups Trojanersicher (V2) - on https://cloudisevil.com

You also can searh vor sysops.tv or zfs. rocks on YouTube #miyagi - an english Tutorial will follow!

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
Proxmox Backup Server Datastore has to be Setup on Source
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

So how do you get back to Business, if your Source fails

Option A

Assign a new Proxmox Machine to your Proxmox Backup Server and restore all necessary VMs and Containers

Option B

Use your Miyagi System to get live

1.  Rename your Datasets
    
    zfs create rpool/data/pveold
    zfs rename rpool/repl/pveold/data rpool/data/pveold/data

2. Create a new PVE Datastore

   Type ZFS
   Name rpool-data-pveold-data ZFS-POOL: rpool/data/pveold/data Content: Disk Image, Container
   Check if your Disks show up in the new Datastore

3. Copy Configs (Please verify VMID from PBS ist not on Source System

   cp rpool/data/pveold/PMconf/etc/pve/nodes/pveold/qemu-server /etc/pve/qemu-server
   cp rpool/data/pveold/PMconf/etc/pve/nodes/pveold/lxc /etc/pve/lxc

4. Rename Datastore Names in new Configs

   cd /etc/pve/qemu-server
   sed -i 's/local-zfs:/rpool-data-pveold-data/g' *.conf

   cd /etc/pve/lxc
   sed -i 's/local-zfs:/rpool-data-pveold-data/g' *.conf

5. Optional repeat this Steps for a Second ZFS Pool and be aware of duplicate Names
6. Start your VMs
7. optional: run our Postinstaller


