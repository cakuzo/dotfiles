#!/bin/bash

IP=${1:-`/sbin/ifconfig eth0|grep inet|awk '{print $2}'|cut -d: -f2`}
TMP=/root
AUDITDIR=AUDIT
#UNAME=`uname -n|cut -d. -f1`
UNAME=${2:-`uname -n|cut -d. -f1`}
DIR=${TMP}/${AUDITDIR}_${IP}_${UNAME}
SHELLREGEX="(/bin/bash|/bin/ksh|/bin/sh|/sbin/sh)"

if [[ ! -e ${DIR} ]]
then
    echo -e "\t\t[+] creating ${DIR}"
    mkdir ${DIR}
else
    echo -e "\t\t[-] ${DIR} exists, removing log files"
    rm ${DIR}/*.log
fi

echo -e "\t\t[+] gathering info"
# local accounts (bash_history, authorized_keys)
while read account; do
    if [[ ${account} =~ ${SHELLREGEX} ]]; then
        USERNAME=`echo ${account}|cut -d: -f1`
        USERHDIR=`echo ${account}|cut -d: -f6`
        USERSHEL=`echo ${account}|cut -d: -f7`
        if [[ (-e ${USERHDIR}/.ssh/authorized_keys) || (-e ${USERHDIR}/.ssh/authorized_keys2) ]]; then
            cat ${USERHDIR}/.ssh/authorized_keys* > ${DIR}/u_${USERNAME}_authkeys.log
        fi
        if [[ -e ${USERHDIR}/.bash_history ]]; then
            cat ${USERHDIR}/.bash_history > ${DIR}/u_${USERNAME}_bash_history.log
        fi
        if [[ `grep -i PRIVATE ${USERHDIR}/.ssh/*` != "" ]]; then
            echo -e "private keys found on \"${account}\" account" > ${DIR}/u_${USERNAME}_ssh_priv_keys.log
            grep -i PRIVATE ${USERHDIR}/.ssh/* 2>/dev/null >> ${DIR}/u_${USERNAME}_ssh_priv_keys.log
        fi
        crontab -l > ${DIR}/crontab_${USERNAME}.log
    fi
done < /etc/passwd
# tcp timestamp
cat /proc/sys/net/ipv4/tcp_timestamps > ${DIR}/tcp_timestamp.log
# all /etc/ and its permissions
cp -Ppr /etc/ ${DIR}/etc
find /etc -exec ls -al {} \; > ${DIR}/etc/permissions.log
# getting cpu and mem info
cat /proc/cpuinfo > ${DIR}/cpuinfo.log
cat /proc/meminfo > ${DIR}/meminfo.log
free -m > ${DIR}/free_mem.log
# vmstat
vmstat 2 10 > ${DIR}/vmstat.log
# ssh options
grep -iv '^#' /etc/ssh/sshd_config | grep -iE '(root|perm|auth)' > ${DIR}/ssh_options.log
# permissions of /home and /root
ls -ald /root /home  > ${DIR}/dir_permissions.log 2>&1
# permissions in home dir
find /home -type d -maxdepth 5 -exec ls -dl {} \; > ${DIR}/home_dirs.log 2>&1
# permissions of debian-sys-main
# os version
OSES="/etc/annvix-release /etc/arch-release /etc/arklinux-release /etc/aurox-release /etc/blackcat-release /etc/cobalt-release /etc/conectiva-release /etc/debian_version /etc/debian_release /etc/fedora-release /etc/gentoo-release /etc/immunix-release /etc/knoppix_version /etc/lfs-release /etc/linuxppc-release /etc/mandrake-release /etc/mandriva-release /etc/mandrake-release /etc/mandakelinux-release /etc/mklinux-release /etc/nld-release /etc/pld-release /etc/redhat-release /etc/redhat_version /etc/slackware-version /etc/slackware-release /etc/e-smith-release /etc/release /etc/sun-release /etc/SuSE-release /etc/novell-release /etc/sles-release /etc/tinysofa-release /etc/turbolinux-release /etc/lsb-release /etc/ultrapenguin-release /etc/UnitedLinux-release /etc/va-release /etc/yellowdog-release"
for os in ${OSES}; do
    if [[ -e ${os} ]]; then
        cp ${os} ${DIR}/`basename ${os}`
    fi
done
if [[ `which lsb_release` != "" ]]; then lsb_release -a > ${DIR}/os_version.log 2>&1; fi
#cat /etc/debian_version | grep -v '^#' | grep -v ^$ > ${DIR}/os_version.log 2>&1
# auto apt and fail2ban
if [[ `which dpkg` != "" ]]; then dpkg -l|grep -iE '(nagios|unattended|fail2|rkhunter|unhide|shorewall|iptables)'  > ${DIR}/dpkg_list.log 2>&1; fi
if [[ `which rpm` != "" ]]; then rpm -qa|grep -iE '(nagios|unattended|fail2|rkhunter|unhide|shorewall|iptables)'  > ${DIR}/rpm_list.log 2>&1; fi
# nattended upgrades
if [[ -e /var/log/unattended-upgrades/ ]]; then
    ls -al /var/log/unattended-upgrades/ > ${DIR}/unattended.log 2>&1
fi
# iptables
iptables -L -n > ${DIR}/iptables.log 2>&1
iptables -L -n -t nat > ${DIR}/iptables.log 2>&1
iptables-save > ${DIR}/iptables-save 2>&1
# suid and sgid files/dirs
##find / \( -perm -4000 -o -perm -2000 -o -perm -1000 \) -type f -exec /bin/ls -ld {} \; > ${DIR}/file_root.log 2>&1
# word writable files
##find / -perm -2 '!' -type l -exec /bin/ls -ld {} \; > ${DIR}/file_writ.log 2>&1
# files and dirs owned by root and accessible by others
# find / \( -user root -o -group root -o -perm +o=rx -o -perm +o=rw -o -perm +o=r \)
# Mounted file systems
mount > ${DIR}/mount.log 2>&1
# df -h
df -h > ${DIR}/df.log 2>&1
# fdisk
fdisk -l > ${DIR}/fdisk.log 2>&1
# RPC services
rpcinfo -p > ${DIR}/rpc.log 2>&1
# Exported filesystems
[ -n "`which showmount`" ]  && showmount -e  > ${DIR}/exports.log 2>&1
# Processes
ps auxwww  > ${DIR}/ps.log 2>&1
# Patches
which dpkg >/dev/null 2>&1 && dpkg --get-selections "*" > ${DIR}/dpkg.log 2>&1
# Debsums
which debsums >/dev/null 2>&1 && debsums  > ${DIR}/debsums.log 2>&1
# uname, OS ver
uname -a > ${DIR}/uname.log 2>&1
# last logged IPs
last -a > ${DIR}/last.log 2>&1
# uptime, load
uptime > ${DIR}/uptime.log 2>&1
# all processes
netstat -an > ${DIR}/netstat.log 2>&1
# listening
netstat -an | grep -w LISTEN > ${DIR}/netstat.log 2>&1
# port -> proc
lsof -Pi4 -n > ${DIR}/lsof.log 2>&1
# sudoers
cat /etc/sudoers | grep -v '^#' | grep -v ^$ > ${DIR}/sudoers.log 2>&1
# limits
cat /etc/security/limits.conf | grep -v '^#' | grep -v ^$ > ${DIR}/limits.log 2>&1
# group
cat /etc/group | grep -v '^#' | grep -v ^$ > ${DIR}/group.log 2>&1
# passwd
cat /etc/passwd | grep -v '^#' | grep -v ^$ > ${DIR}/passwd.log 2>&1
# umask
umask > ${DIR}/umask.log 2>&1
# shadow empty pass
while read entry
do
    USER=`echo ${entry}|cut -d: -f1`
    PASS=`echo ${entry}|cut -d: -f2`
    if [[ ${PASS} == '' ]]
    then
        echo ${USER} > ${DIR}/shadow_empty.log
    fi
done < /etc/shadow
# check IP addresses
ip addr show > ${DIR}/ip.log
# rkhunter
if [[ `which rkhunter` != '' ]]
then
    rkhunter -c --sk --vl -l ${DIR}/rkhunter.log 2>&1 > /dev/null
fi
# ossec
ps awwwfxu | grep -v grep | grep ossec > ${DIR}/ossec.log
# unhide
if [[ `which unhide` != '' ]]
then
    echo '#### unhide proc' > ${DIR}/unhide.log
    unhide proc >> ${DIR}/unhide.log
    echo '#### unhide sys' >> ${DIR}/unhide.log
    unhide sys >> ${DIR}/unhide.log
    echo '#### unhide brute' >> ${DIR}/unhide.log
    unhide brute >> ${DIR}/unhide.log
    echo '#### unhide tcp' >> ${DIR}/unhide.log
    unhide-tcp >> ${DIR}/unhide.log
fi

# /opt and /var/opt content for further analysis
if [[ `ls -A /opt/` != "" ]]; then
    find /opt -exec ls -al {} \; > ${DIR}/opt.log
fi
if [[ `ls -A /var/opt/` != "" ]]; then
    find /var/opt -exec ls -al {} \; > ${DIR}/var_opt.log
fi

# sysctl
sysctl -a > ${DIR}/sysctl.log

# wrap all up and finish
cd ${TMP}
echo -e "\t\t[+] compressing data"
tar -zcf ${AUDITDIR}_null.tar.gz ${AUDITDIR}_${IP}_${UNAME} 2>&1
chmod 777 ${AUDITDIR}_null.tar.gz
echo -e "\t\t[+] you may remove ${DIR}"
