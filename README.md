# miyagi-pbs-zfs
Secure Proxmox PVE with Proxmox Backup Server PBS and ZFS Pull Replication with a mostly turned off System

What it does Miyagi says, best Defense, not be present

Proxmox Backupserver is running unnecessarly 24/7 ZFS Replication is usually done by a zfs send, so its a push

What if our Backup/Replicaserver is turned off most the time, nobody can attack it

Consider not using a Gateway, use Routes!

What we do...

Turning on the Computer with a @reboot Cron Pulling all Datasets with ZFS Reporting ZFS Replication with 100% certainty to backuped PVE Host using Check_MK and checkzfs.py from #bashclub

Regarding to the Weekday doing Maintenance on Proxmox Backup Server for getting Space Triggering a Push (only Way to do) Backup to PBS and checking Exitcode for Report Reporting PBS Result with 100% certainty in compact OK/WARN State to backuped PVE Host using Check_MK

Verifying older Backups Protecting the PBS Backups with a ZFS Snapshot

TURNING OFF THE MACHINE!!!
