#!/usr/bin/env bash
#########################################################################
# Script:       check_zpools.sh
# Purpose:      Nagios plugin to monitor status of zfs pool
# Authors:      Aldo Fabi               First version (2006-09-01)
#               vitaliy@gmail.com       Forked (2013-02-04)
#               Claudio Kuenzler        Complete redo, perfdata, etc (2013)
#               Thomas Rechberger       rework (2014-01-04)
#               Orhan Cakan             rework (2015-04-01)
# History:
# 2006-09-01    Original first version
# 2006-10-04    Updated (no change history known)
# 2013-02-04    Forked and released
# 2013-05-08    Make plugin work on different OS, pepp up plugin
# 2013-05-09    Bugfix in exit code handling
# 2013-05-10    Removed old exit vars (not used anymore)
# 2013-05-21    Added performance data (percentage used)
# 2013-07-11    Bugfix in zpool health check
# 2014-01-04    add non percentage warn/crit, replace which (doesnt work in BSD), minor changes
# 2015-04-01    fixed some typos and deleted some unecessary characters in performance data eg.")"
#########################################################################
# Set path
PATH=$PATH:/usr/sbin:/sbin
export PATH
# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
### Begin vars
help="check_zpools.sh (c) 2006-2014 several authors\n
Usage: $0 -p (poolname) [-w warn] [-c crit]\n
Example 1) pool tank, free space in %, with warning 80%, critical 90%: $0 -p tank -w 80% -c 90%\n
Example 2) all pools, free space in G, with warning 200G, critical 100G: $0 -p ALL -w 200 -c 100\n
Example 3) pool tank, health status: $0 -p tank"
### End vars
#########################################################################
# Check necessary commands are available
if ! command -v zpool >/dev/null; then
echo "UNKNOWN: zpool does not exist, please check if command exists"
exit ${STATE_UNKNOWN}
fi
#########################################################################
# Check for people who need help - aren't we all nice ;-)
if [ "${1}" = "--help" -o "${#}" = "0" ];
       then
       echo -e "${help}";
       exit ${STATE_UNKNOWN};
fi
#########################################################################
# Get user-given variables
while getopts "p:w:c:" Input;
do
       case ${Input} in
       p)      pool=${OPTARG};;
       w)      warn=${OPTARG};;
       c)      crit=${OPTARG};;
       *)      echo -e $help
               exit ${STATE_UNKNOWN};
               ;;
       esac
done
#########################################################################
# warn and crit do not have mixed % and value ?
if [[ $warn == *% || $crit == *% ]]; then
  if ! [[ $warn == *% && $crit == *% ]]; then
    echo "UNKNOWN: mixing of percentage and normal values are not allowed on warn/crit"
    exit ${STATE_UNKNOWN}
  fi
elif [[ $warn == *% && $crit == *% ]]; then
  if [[ ${warn//[%]/} -gt ${crit//[%]/} ]]; then
    echo "UNKNOWN: input makes no sense, warning % is bigger than critical %"
    exit ${STATE_UNKNOWN}
  fi
elif [[ $warn && $crit ]]; then
  if [[ $crit -gt $warn ]]; then
    echo "UNKNOWN: input makes no sense, critical free space is bigger than warning free space"
    exit ${STATE_UNKNOWN}
  fi
fi
#########################################################################
# What needs to be checked?
## Check all pools
if [[ $pool == "ALL" || $pool == "all" ]]; then
  POOLS=($(zpool list -Ho name))
  p=0
  for POOL in ${POOLS[*]}
  do
    if [[ $warn == *% && $crit == *% ]]; then #warn and crit was specified with perc?
      CAPACITY=$(zpool list -Ho capacity $POOL | awk -F"%" '{print $1}')
      if [[ $CAPACITY -gt ${crit//[%]/} ]]; then
        error[${p}]="POOL $POOL usage is CRITICAL (threshold ${crit}"; fcrit=1
      elif [[ $CAPACITY -gt ${warn//[%]/} && $CAPACITY -lt ${crit//[%]/} ]]; then
        error[$p]="POOL $POOL usage is WARNING (threshold ${warn}"
      fi
    elif [[ $warn && $crit ]]; then #warn and crit was set at all? this implies also its without perc
      CAPACITY=$(zpool list -Ho free $POOL | awk -F"G" '{print $1}')
      if [[ $CAPACITY -lt ${crit//[%]/} ]]; then
        error[${p}]="POOL $POOL usage is CRITICAL (threshold ${crit}G"; fcrit=1
      elif [[ $CAPACITY -lt ${warn//[%]/} && $CAPACITY -gt ${crit//[%]/} ]]; then
        error[$p]="POOL $POOL usage is WARNING (threshold ${warn}G"
      fi
    elif [[ $warn || $crit ]]; then #if warn or crit was set
      echo "UNKNOWN: warning or critical detected but the other is missing"
      exit ${STATE_UNKNOWN}
    fi

    HEALTH=$(zpool list -Ho health $POOL)
    if [ $HEALTH != "ONLINE" ]; then
      error[${p}]="$POOL health is $HEALTH"; fcrit=1
    fi
    perfdata[$p]="$POOL=${CAPACITY}"
    let p++
  done

  if [[ ${#error[*]} -gt 0 ]]; then
    if [[ $fcrit -eq 1 ]]; then
      echo "CRITICAL: ZFS Pool Alarm: ${error[*]}|${perfdata[*]}"; exit ${STATE_CRITICAL}
    else
      echo "WARNING: ZFS Pool Alarm: ${error[*]}|${perfdata[*]}"; exit ${STATE_WARNING}
    fi
  else
    echo "OK: All ZFS Pools Ok (${POOLS[*]})|${perfdata[*]}"; exit ${STATE_OK}
  fi

## Check single pool, play it again Sam ...
else
  HEALTH=$(zpool list -Ho health $pool)
  if [ $HEALTH != "ONLINE" ]; then
    echo "CRITICAL: ZFS Pool $pool health is $HEALTH"
    exit ${STATE_CRITICAL}
  fi

  if [[ $warn == *% && $crit == *% ]]; then
    CAPACITY=$(zpool list -Ho capacity $pool | awk -F"%" '{print $1}')
    if [[ $CAPACITY -gt ${crit//[%]/} ]]; then
      echo "CRITICAL: ZFS Pool $pool usage is CRITICAL (threshold ${crit})|$pool=${CAPACITY}%"; exit ${STATE_CRITICAL}
    elif [[ $CAPACITY -gt ${warn//[%]/} && $CAPACITY -lt ${crit//[%]/} ]]; then
      echo "WARNING: ZFS Pool $pool usage is WARNING (threshold ${warn})|$pool=${CAPACITY}%"; exit ${STATE_WARNING}
    else
      echo "OK: ZFS POOL OK ($pool)|$pool=${CAPACITY}"
      exit ${STATE_OK}
    fi
  elif [[ $warn && $crit ]]; then
    CAPACITY=$(zpool list -Ho free $pool | awk -F"G" '{print $1}')
    if [[ $CAPACITY -lt $crit ]]; then
      echo "CRITICAL: ZFS Pool $pool usage is CRITICAL (threshold ${crit}G)|$pool=${CAPACITY}G"; exit ${STATE_CRITICAL}
    elif [[ $CAPACITY -lt $warn && $CAPACITY -gt $crit ]]; then
      echo "WARNING: ZFS Pool $pool usage is WARNING (threshold ${warn}G)|$pool=${CAPACITY}G"; exit ${STATE_WARNING}
    else
      echo "OK: ZFS Pool Ok ($pool)|$pool=${CAPACITY}"
      exit ${STATE_OK}
    fi
  elif [[ ! $warn && ! $crit ]]; then #if no warning/critical was specified and we are still here, print ok
    echo "OK: ZFS Pool Ok ($pool)"
    exit ${STATE_OK}
  elif [[ $warn || $crit ]]; then #warning or critical was set, but not both
    echo "UNKNOWN: warning or critical detected but the other is missing"
    exit ${STATE_UNKNOWN}
  fi
fi

echo "UNKNOWN - Should never reach this part"
exit ${STATE_UNKNOWN}
