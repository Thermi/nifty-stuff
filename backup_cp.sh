#! /bin/bash

trap exit SIGHUP

mirror="no"

flags="-aux --preserve=all"
key_file="<path to the key file goes here>"
backupLUKSUUID="<UUID of the LUKS partition goes here>"
backupMountpoint="<path to the backup mountpoint"
newFolder="$backupMountpoint/$(date -I)"

backupDrive=$(ls -l /dev/disk/by-uuid/$backupLUKSUUID | cut -d " " -f 11 | tr -d "./1234567890")

rootUsage=$(df / | tr -s " " | cut -d " " -f 3 | tail -n 1)
bootUsage=$(df /boot | tr -s " " | cut -d " " -f 3 | tail -n 1)
let computerUsage=rootUsage+bootUsage

if [[ ! -a /dev/disk/by-uuid/$backupLUKSUUID ]]
then
	echo "backup drive is not on the system. Trying to discover it ..."
	for i in `ls /sys/class/scsi_host/`
	do
		if ! ls /sys/class/scsi_host/$i/device/target*
		then
			echo "SATA port $i is unoccupied."
			echo "Trying to rescan $i"
			echo "0 0 0" > /sys/class/scsi_host/$i/scan
			echo "Rescanned $i"
		else
			echo "SATA port $i is already occupied."
		fi
	done
	sleep 2s

	if [[ ! -a /dev/disk/by-uuid/$backupLUKSUUID ]]
	then
		echo "Could not discover backup drive. Exiting ..."
		exit 1
	fi
fi

if [[ ! -a /dev/mapper/backup ]]
then
	if ! cryptsetup luksOpen "/dev/disk/by-uuid/$backupLUKSUUID" backup --key-file $key_file
	then
		echo "Opening of the container failed. Exiting ..."
		exit 1
	fi
fi

if ! mountpoint -q "$backupMountpoint"
then
	if ! mount /dev/mapper/backup "$backupMountpoint"
	then
		echo "Mounting the volume failed. Exiting ..."
		exit 1
	fi
fi

availableBackupCapacity=$(df -l "$backupMountpoint" | tr -s " " | cut -d " " -f 4 | tail -n 1)

# if there is no more space for a further backup, delete the oldest one 
if [ $availableBackupCapacity -lt $computerUsage ] 
then
# remove the oldest backup space
	rm -rf $backupMountpoint/$(ls $backupMountpoint | head -n 1)
fi

mkdir -p "$newFolder/arch"
mkdir -p "$newFolder/Datengrab"
mkdir -p "$newFolder/boot"

cp $flags / "$newFolder/"
cp $flags /boot/ "$newFolder/boot/"

wait $(jobs -p)

# unmount, close the device and shut down the drive if there aren't any open file descriptors on the mountpoint
# if there are still open files, check if there is still an open one periodically
openFiles=`lsof | fgrep -- "$backupMountpoint"`
slept=0
while [[ `wc -l < <(echo "$openFiles")` > 0 ]]
do
	sleep 10s
	let slept+=10
	if [[ "$slept" > 3600 ]]
	then
		echo "Slept for an hour. Exiting ..."
		exit 1
	fi
done

umount "$backupMountpoint"
cryptsetup luksClose backup
echo 1 > "/sys/bus/scsi/devices/$(lsscsi | grep $backupDrive | cut -d ' ' -f 1 | tr -d '[]')/delete"