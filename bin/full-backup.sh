#!/usr/bin/env bash
# Does a Full System Backup with tar (only of ext file systems)
# paths to exclude can be added to /root/backup/.exclude
#
# !!! This is currently only tested on Ubuntu 14.04 LTS !!! 

# Backup destination
backdest=/root/backup
[ -d /root/backup ] || mkdir -p /root/backup

# backup archive name
pc=$(hostname -s)
distro=$(lsb_release -is)$(lsb_release -rs)
date=$(date "+%Y%m%d-%H%M%S")
backupfile="$backdest/$pc-$distro-full-$date.tgz"
excludefile=$backdest/.exclude
originsize=$(df -h / | awk '{print $3}' | tail -n1)

[ -r $backupfile ] && { 
    echo Backup file $backupfile already exists 1>&2
    exit 1
}

# check if needed tools are installed
dpkg-query -W -f='${status}' pv | grep -c "install ok installed" >/dev/null || {
    apt-get install pv
}

#Exclude file location
[ -s $excludefile ] || {
echo creating excludefile
find / -maxdepth 1 -printf "%F %p\n" | grep -v '^ext[234]' | cut -d" " -f2 > $excludefile
cat >>$excludefile <<EOF
/tmp
/run
/var/spool
/root/backup
/lost+found
EOF
}
echo "excluding directories defined in $excludefile:"
cat $excludefile
echo ===
echo "available: $(df -h / | awk '{print $4}' | tail -n1)"
echo "used:      $originsize"
echo === 
echo -n "Are you ready to backup? (y/n): "
read continue
[ $continue != "y" ] && exit 1

tar --exclude-from=$excludefile -cf - / | pv -s $(df -k / | awk '{print $3}' | tail -n1)k | gzip > $backupfile && {
    ls $backupfile
    echo done
}
