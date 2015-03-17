#!/bin/bash
# check_snmp_synology for nagios version 1.3
# 16.03.2015  Orhan Cakan, Austria
# 03.10.2014  Jur Groen, Syso IT Services, The Netherlands
# 30.04.2013  Nicolas Ordonez, Switzerland
#---------------------------------------------------
# this plugin checks the health of your Synology NAS
# - System status (Power, Fans)
# - Disks status 
# - RAID status
# - DSM update status
#
# this plugin now makes use of SNMP V3 for enhanced security
# Tested with DSM 5.0
#---------------------------------------------------
# Based on http://download.synology.com/download/ds/userguide/Synology_DiskStation_MIB_Guide_enu_20110725.pdf
# Updated version http://ukdl.synology.com/download/Document/MIBGuide/Synology_DiskStation_MIB_Guide.pdf
#---------------------------------------------------

SNMPVERSION="3"
SNMPWALK=$(which snmpwalk)
SNMPGET=$(which snmpget)

HOSTNAME=""
option_found=0
healthStatus=0
healthString=""
verbose="no"
legacyDSM="0"

#OID declarations
OID_syno="1.3.6.1.4.1.6574"
OID_model="1.3.6.1.4.1.6574.1.5.1.0"
OID_serialNumber="1.3.6.1.4.1.6574.1.5.2.0"
OID_DSMVersion="1.3.6.1.4.1.6574.1.5.3.0"
OID_upgradeAvailable="1.3.6.1.4.1.6574.1.5.4.0"
OID_systemStatus="1.3.6.1.4.1.6574.1.1.0"
OID_powerStatus="1.3.6.1.4.1.6574.1.3.0"
OID_systemFanStatus="1.3.6.1.4.1.6574.1.4.1.0"
OID_CPUFanStatus="1.3.6.1.4.1.6574.1.4.2.0"
OID_temp="1.3.6.1.4.1.6574.1.2.0"

OID_disk=""
OID_diskID="1.3.6.1.4.1.6574.2.1.1.2"
OID_diskModel="1.3.6.1.4.1.6574.2.1.1.3"
OID_diskStatus="1.3.6.1.4.1.6574.2.1.1.5"
OID_diskTemp="1.3.6.1.4.1.6574.2.1.1.6"

OID_RAID=""
OID_RAIDName="1.3.6.1.4.1.6574.3.1.1.2"
OID_RAIDStatus="1.3.6.1.4.1.6574.3.1.1.3"

usage()
{
        echo "usage: ./check_snmp_synology -u [snmp username] -p [snmp password] -h [hostname] [-v verbose]"
        echo ""
        exit 3
}

while getopts u:p:h:v OPTNAME; do
        case "$OPTNAME" in
        u)
                SNMPUSERNAME="$OPTARG"
                option_found=$(($option_found + 1))
                ;;
        p)
                SNMPPASSWORD="$OPTARG"
                option_found=$(($option_found + 1))
                ;;
        h)
                HOSTNAME="$OPTARG"
                option_found=$(($option_found + 1))
                ;;
        v)
                verbose="yes"
                ;;
        *)
                usage
                ;;
        esac
done

if [ $option_found -lt 3 ] || [ "$HOSTNAME" = "" ] ; then
    usage
else
    nbDisk=`$SNMPWALK -OQne -t 10 -v 3 -l authNoPriv -u $SNMPUSERNAME  -a MD5 -A $SNMPPASSWORD $HOSTNAME 1.3.6.1.4.1.6574.2.1.1.2 2> /dev/null | wc -l `
    nbRAID=`$SNMPWALK -OQne -t 10 -v 3 -l authNoPriv -u $SNMPUSERNAME  -a MD5 -A $SNMPPASSWORD $HOSTNAME 1.3.6.1.4.1.6574.3.1.1.2 2> /dev/null | wc -l `

    for i in `seq 1 $nbDisk`; do
      OID_disk="$OID_disk $OID_diskID.$(($i-1)) $OID_diskModel.$(($i-1)) $OID_diskStatus.$(($i-1)) $OID_diskTemp.$(($i-1)) " 
    done

    for i in `seq 1 $nbRAID`; do
      OID_RAID="$OID_RAID $OID_RAIDName.$(($i-1)) $OID_RAIDStatus.$(($i-1))" 
    done

    legacyDSM=$($SNMPGET -OQne -t 10 -v 3 -l authNoPriv -u $SNMPUSERNAME  -a MD5 -A $SNMPPASSWORD $HOSTNAME $OID_model 2> /dev/null | grep -ci 'No Such Object available')

    if [ $legacyDSM -gt 0 ]; then
        syno=`$SNMPGET -OQne -t 10 -v 3 -l authNoPriv -u $SNMPUSERNAME  -a MD5 -A $SNMPPASSWORD $HOSTNAME $OID_systemStatus $OID_powerStatus $OID_systemFanStatus $OID_CPUFanStatus $OID_temp $OID_disk $OID_RAID 2> /dev/null`
        if [ "$?" != "0" ] ; then
            echo "CRITICAL - Problem with SNMP request"
            exit 2
        fi 
    else 
        syno=`$SNMPGET -OQne -t 10 -v 3 -l authNoPriv -u $SNMPUSERNAME  -a MD5 -A $SNMPPASSWORD $HOSTNAME $OID_model $OID_serialNumber $OID_upgradeAvailable $OID_DSMVersion $OID_systemStatus $OID_powerStatus $OID_systemFanStatus $OID_CPUFanStatus $OID_temp $OID_disk $OID_RAID 2> /dev/null`
        if [ "$?" != "0" ] ; then
            echo "CRITICAL - Problem with SNMP request"
            exit 2
        fi 

        model=$(echo "$syno" | grep $OID_model | cut -d "=" -f2)
        serialNumber=$(echo "$syno" | grep $OID_serialNumber | cut -d "=" -f2)
        DSMVersion=$(echo "$syno" | grep $OID_DSMVersion | cut -d "=" -f2)
        upgradeAvailable=$(echo "$syno" | grep $OID_upgradeAvailable | cut -d "=" -f2)

        if [ "$upgradeAvailable" -eq "1" ] ; then OID_upgradeAvailable="Available"     healthStatus=3 ;   fi
        if [ "$upgradeAvailable" -eq "2" ] ; then  OID_upgradeAvailable="Unavailable"  healthStatus=0 ;   fi
        if [ "$upgradeAvailable" -eq "3" ] ; then OID_upgradeAvailable="Connecting"    healthStatus=0 ;   fi
        if [ "$upgradeAvailable" -eq "4" ] ; then OID_upgradeAvailable="Disconnected"  healthStatus=0 ;   fi
        if [ "$upgradeAvailable" -eq "5" ] ; then OID_upgradeAvailable="Others"        healthStatus=0 ;   fi  
    fi

    if [ $legacyDSM != "0" ]; then
        healthString="Synology NAS"
    else
        healthString="Synology $model (s/n:$serialNumber, $DSMVersion)"
    fi
    
    RAIDName=$(echo "$syno" | grep $OID_RAIDName | cut -d "=" -f2)
    RAIDStatus=$(echo "$syno" | grep $OID_RAIDStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    #Check system status
    systemStatus=$(echo "$syno" | grep $OID_systemStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')

    if [ "$systemStatus" != "1" ] ; then
        if [ "$systemStatus" = "2" ] ; then 
            systemStatus="Failed"
        fi
        healthStatus=2
        healthString="$healthString, System status: $systemStatus "
    else
        systemStatus="Normal"
    fi

    #Check power status
    powerStatus=$(echo "$syno" | grep $OID_powerStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')

    if [ "$powerStatus" != "1" ]; then
        if [ "$powerStatus" = "2" ]; then
            powerStatus="Failed"
        fi
        healthStatus=2
        healthString="$healthString, Power status: $powerStatus"
    else
        powerStatus="Normal"
    fi

    #Check system fan status
    systemFanStatus=$(echo "$syno" | grep $OID_systemFanStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    if [ "$systemFanStatus" != "1" ] ; then
        if [ "$systemFanStatus" = "2" ] ; then
            systemFanStatus="Failed";
        fi
        healthStatus=2
        healthString="$healthString, System fan status: $systemFanStatus "
    else
        systemFanStatus="Normal"
    fi

    #Check CPU fan status
    CPUFanStatus=$(echo "$syno" | grep $OID_CPUFanStatus | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
    if [ "$CPUFanStatus" != "1" ] ; then
        if [ "$CPUFanStatus" = "2" ] ; then
            CPUFanStatus="Failed";
        fi
        healthStatus=2
        healthString="$healthString, CPU fan status: $CPUFanStatus "
    else
        CPUFanStatus="Normal"
    fi

    #Check all disk status
    for i in `seq 1 $nbDisk`; do
            diskID[$i]=$(echo "$syno" | grep "$OID_diskID.$(($i-1)) " | cut -d "=" -f2)
            diskModel[$i]=$(echo "$syno" | grep "$OID_diskModel.$(($i-1)) " | cut -d "=" -f2)
            diskStatus[$i]=$(echo "$syno" | grep "$OID_diskStatus.$(($i-1)) " | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')
            diskTemp[$i]=$(echo "$syno" | grep "$OID_diskTemp.$(($i-1)) " | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')

            if [ "${diskStatus[$i]}" != "1" ] && [ "${diskStatus[$i]}" != "2" ] ; then   
                if [ "${diskStatus[$i]}" = "3" ] ; then diskStatus[$i]="NotInitialized"; fi  
                if [ "${diskStatus[$i]}" = "4" ] ; then diskStatus[$i]="SystemPartitionFailed"; fi  
                if [ "${diskStatus[$i]}" = "5" ] ; then diskStatus[$i]="Crashed"; fi  
                healthStatus=2  
                healthString="$healthString, problem with ${diskID[$i]} (model:${diskModel[$i]})   status:${diskStatus[$i]} temperature:${diskTemp[$i]} C "  
            elif [ "${diskStatus[$i]}" = "2" ] ; then 
                diskStatus[$i]="Initialized"  
            else  
                diskStatus[$i]="Normal"  
            fi  
    done  

    #Check all RAID volume status
    for i in `seq 1 $nbRAID`; do
        RAIDName[$i]=$(echo "$syno" | grep $OID_RAIDName.$(($i-1)) | cut -d "=" -f2)
        RAIDStatus[$i]=$(echo "$syno" | grep $OID_RAIDStatus.$(($i-1)) | cut -d "=" -f2 | sed 's/^[ \t]*//;s/[ \t]*$//')

        if [ "${RAIDStatus[$i]}" != "1" ] ; then
            if [ "${RAIDStatus[$i]}" = "2" ] ; then  RAIDStatus[$i]="Repairing"; fi
            if [ "${RAIDStatus[$i]}" = "3" ] ; then  RAIDStatus[$i]="Migrating"; fi
            if [ "${RAIDStatus[$i]}" = "4" ] ; then  RAIDStatus[$i]="Expanding"; fi
            if [ "${RAIDStatus[$i]}" = "5" ] ; then  RAIDStatus[$i]="Deleting"; fi
            if [ "${RAIDStatus[$i]}" = "6" ] ; then  RAIDStatus[$i]="Creating"; fi
            if [ "${RAIDStatus[$i]}" = "7" ] ; then  RAIDStatus[$i]="RaidSyncing"; fi
            if [ "${RAIDStatus[$i]}" = "8" ] ; then  RAIDStatus[$i]="RaidParityChecking"; fi
            if [ "${RAIDStatus[$i]}" = "9" ] ; then  RAIDStatus[$i]="RaidAssembling"; fi
            if [ "${RAIDStatus[$i]}" = "10" ] ; then RAIDStatus[$i]="Canceling"; fi
            if [ "${RAIDStatus[$i]}" = "11" ] ; then RAIDStatus[$i]="Degrade"; fi
            if [ "${RAIDStatus[$i]}" = "12" ] ; then RAIDStatus[$i]="Crashed"; fi
            healthStatus=2
            healthString="$healthString, RAID status ($RAIDName ): $RAIDStatus "
        else
            RAIDStatus[$i]="Normal"
        fi
    done

    # STATUS OUTPUT
    if [ "$healthStatus" = "0" ] ; then
        echo "OK - $healthString is in good health"
        EXITCODE=0 # OK
    elif [ "$healthStatus" = "3" ] ; then
        echo "WARNING - $healthString needs to be updated"
        EXITCODE=1 # WARNING
    else
        echo "CRITICAL - $healthString"
        EXITCODE=2 # CRITICAL
    fi

    # VERBOSE AND LEGACY OUTPUT
    if [ "$verbose" = "yes" ]; then 
        if [ $legacyDSM == "0" ]; then
            echo "Synology model:   $model"
            echo "Synology s/n:     $serialNumber"
            echo "DSM Version:      $DSMVersion"
            echo "DSM Version update:     $OID_upgradeAvailable"
        fi
        echo "System Status:     $systemStatus"
        echo "Power Status:      $powerStatus"
        echo "System Fan Status: $systemFanStatus"
        echo "CPU Fan Status:    $CPUFanStatus"
        echo "Number of disks:   $nbDisk"

        for i in `seq 1 $nbDisk`; do
            echo "${diskID[$i]} (model:${diskModel[$i]}) status:${diskStatus[$i]} temperature:${diskTemp[$i]} C"
        done 

        echo "Number of RAID volume: $nbRAID"
        for i in `seq 1 $nbRAID`; do
            echo "${RAIDName[$i]} status: ${RAIDStatus[$i]}"
        done
    fi

    exit $EXITCODE

fi
