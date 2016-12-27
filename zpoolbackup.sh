#!/bin/bash 

DESCRIPTION="Creates a snapshot of a zpool and rsyncs this to another locally \nmounted filesystem (zpool or legacy)"

COPYRIGHT="(C) 2009-2011 censhare AG Munich"
# Author: pju@censhare.de 
#
# History
REVISION="pju, censhare AG, 21-Feb-11 if we don't have a date that implements epoch try to use python"
#mht, censhare AG, 22-Jul-10  changed output to outputformat from css-sync
#			      added duration time
#pju, censhare AG, 24-Feb-10  Check for zfs and rsync
#                             Rewrote unmount at exit
#pju, censhare AG, 12-Feb-10  Don't try to send e-mail if we can't obtain FQDN
#pju, censhare AG, 09-Feb-10  Allow use of alternative legacy mountpoint using -f
#                             Mount legacy mounts without using vfstab
#pju, censhare AG, 05-Feb-10  -n/--dry-run instead of -d/--debug
#                             show log in dry-run mode on STDOUT
#                             check e-mail address for @
#pju, censhare AG, 04-Feb-10  sed uses % as delimiter to avoid problems with / in pathes
#                             Fixed severe problems introduced with last changes
#pju, censhare AG, 19-Jan-10  Fixed problems with unmounting legacy mounts
#                             added debug mode
#pju, censhare AG, 02-Dec-09  unmount backup pool only if it wasn't mounted
#                             initially
#                             switch off error e-mails with -e "" 
#                             version information
# pju, censhare AG, 20-Nov-09  use ~/log as log dir if default is not writable
#                              allow non-root users to take backup, 
#                              RBAC privileges provided
# pju, censhare AG, 13-Nov-09  workaround for not GNU id, 
#                              give up if zfs list for backpool fails
#                              specify target e-mail address using switch
# dk,  censhare AG, 19-Oct-09  given name for script and mail subject
# pju, censhare AG, 16-Oct-09  specify source and target on commandline
# pju, censhare AG, 15-Oct-09  mount BAKPOOL only if not mounted yet
# pju, censhare AG, 14-Oct-09  use temporary log file
# vl,  censhare AG, 14-Sep-09  initial version
#

######################
# Example cron entry #
######################
# 45 5 * * 6 /usr/local/sbin/zpoolbackup.sh -p rpool/<pool_to_backup> -b rpool/<backup_pool>

#####################
# Default settings  #
#####################
EMAIL=nagios-admin@censhare.de
LOGFILE=/var/log/zpoolbackup.log       # direct the output from this script to this file
SUBJECT="Probleme beim Zpool-System-Backup"  # subject of the error message sent
                                       # in case of failure
#####################
# Environment       #
#####################
export PATH=/usr/ccs/bin:/usr/local/bin:/opt/csw/sbin:/opt/csw/bin:/usr/sbin:/usr/bin:/usr/ucb:/sbin:/usr/openwin/bin
export LD_LIBRARY_PATH=:/opt/csw/lib:/etc/lib:/usr/lib:/usr/local/lib:/usr/openwin/lib:/usr/dt/lib:/usr/ccs/lib:/usr/td/lib:/usr/ucblib:/usr/local/lib
#####################

# use printf to echo if possible
echo=$(which printf) 2>/dev/null
echo=${echo:-"echo -en"}

# exitreports for exitstates 0 1 2 3 4
# STATES=(OK WARNING CRITICAL UNKNOWN DEPENDENT)
STATES=(successfully WARNING CRITICAL UNKNOWN DEPENDENT)
exitstate=0 # default exit state

# program call
runas=$(basename $0 2>/dev/null)
test $? -eq 0 || runas=$0

##################
# Usage          #
##################
usage () {
    $echo "\n$DESCRIPTION\n"
    $echo "\nUsage: $runas -p <pool_to_backup> -b <backup_pool>\n"
    $echo   "            [ -m <backup_mountpoint>]  [ -e <e-mail_address>]\n"
    $echo   "            [ -f | --force ] [ -n | --dry-run ]\n"
    $echo "\n<pool_to_backup>   : Backup source (ZFS pool)\n"
    $echo   "<backup_pool>      : Target filesystem (ZFS pool)\n"
    $echo   "<backup_mountpoint>: Mountpoint of the backup pool. Only required for legacy mounts\n"
    $echo   "<e-mail_address>   : Receiver of error e-mails. Default: $EMAIL\n                     Set to \"\" to suppress e-mail\n"
    $echo   " -n | --dry-run    : Show what the script would do (no actual snapshots and copies performed)\n"
    $echo   " -f | --force      : Use legacy mount point specified with -m instead of zfs mountpoint\n"
    $echo "\n       $runas -h  | --help   (Provides usage information)\n"
    $echo "       $runas -v  | --version  (Provides version information)\n"
    $echo "\n $runas logs its activities in $LOGFILE\n"
    $echo "\n $COPYRIGHT\n"
}

##################
# Version        #
##################
version () {
    local rev=${REVISION##*, }
    $echo "\n $runas version ${rev%% *}" 
    $echo "\n $COPYRIGHT\n"
}

###################
# Error handling #
###################
critical () {
    if test -w $temp_log; then
        $echo $(date +"%Y-%m-%d_%H:%M:%S")" " >> $temp_log
        $echo "$runas $1\n" | tee -a $temp_log
        test ! -z "$EMAIL" && \
            cat $temp_log | mailx -r $SENDER -s "$SERVER: $SUBJECT ($runas)" $EMAIL;
    else
        $echo "$runas $1\n" 1>&2
    fi
    $echo "    Exiting...\n" 1>&2
    exitstate=2
    exit $exitstate
}

warning () {
    if test -w $temp_log; then
        $echo $(date +"%Y-%m-%d_%H:%M:%S")" " >> $temp_log
        $echo "$runas $1\n" | tee -a $temp_log
    else
        $echo "$runas $1\n" 1>&2
    fi
    exitstate=1
}

unknown () {
    $echo "$runas: $1\n" 1>&2
    usage
    exitstate=3
    exit $exitstate
}

############################
# Parsing the command line #
############################

case "$#" in
    1 | 4 | 5 | 6 | 7 | 8 | 9) ;;
    *) unknown "";;
esac

while test -n "$1" ; do
    case "$1" in
        -p | --pool ) POOL="$2"
           shift 2 ;;
        -b | --backup ) BAKPOOL="$2"
           shift 2 ;;
        -m | --backupmount ) BAKMOUNT="$2"
           shift 2;;
        -e | --email ) EMAIL="$2"
           test "$EMAIL" == "${EMAIL%%@*}" && unknown "E-mail address $EMAIL does not contain a @. Please specify local and remote part!"
           shift 2;;
        -n | --dry-run) DEBUGCMD=echo # echo command instead of running it 
           DEBUGMSG="in dry-run mode (no snapshot, no copies)" # marker text for the log 
           shift;;
        -f | --force ) FORCE=0
           shift;;
        -h | --help ) usage
           exit 0;;
        -v | --version ) version
           exit 0;;
        *) unknown "Unknown option $1"
           usage;;
    esac
done

if test ! -z "$FORCE" && test $FORCE -eq 0; then
    test -z "$BAKMOUNT" && unknown "Please specify legacy mountpoint using -m if using -f option"
fi

##################
# Mount routines #
##################
mount_legacy () {
    echo pfexec mount -F zfs $1 $2 2>> $temp_log 1>&2
    pfexec mount -F zfs $1 $2 2>> $temp_log 1>&2
    if test $? -ne 0; then
        critical "Cannot mount $1 on $2 using legacy mount."
    fi
}

#################
# Cleanup tasks #
#################
cleanup () {
# add temporary log to $LOGFILE and remove it
cat $temp_log >> ${LOGFILE}
if test $? -eq 0; then
    rm $temp_log 2>&1 | tee -a ${LOGFILE}
else
    warning "Can't write ${LOGFILE}. Keeping $temp_log."
fi
}


on_exit () {
    if test -w $temp_log; then
#        $echo "Finished zpoolbackup with state ${STATES[$exitstate]} $(date +"%Y-%m-%d_%H:%M:%S")\n"  >> $temp_log
        $echo "### exit ec=${STATES[$exitstate]} at '$(date +"%d.%m.%Y (%a), um %H:%M:%S")' (time: ${sec}s)."  >> $temp_log


# In dry-run mode show log
if test ! -z $DEBUGCMD; then
    cat $temp_log
fi

        cleanup
    fi
}

# Finally we're prepared to start with our task

trap on_exit EXIT

# temporary log file
time=$(date +"%Y-%m-%d_%H:%M:%S")
for logfile in ${LOGFILE} ~/log/$(basename ${LOGFILE}); do
    logdir=${logfile%$(basename $logfile)}
    test -d ${logdir} || mkdir ${logdir} 
    if test $? -eq 0; then
        temp_log=${logfile}-${time}
        touch $temp_log 2>/dev/null
        if test $? -eq 0; then
            LOGFILE=$logfile
            break
        fi
    else
        warning "Can't create logdirectory ${logdir}"
    fi
done
touch $temp_log || critical "Can't write temporary logfile $temp_log"

###############################
# Get other script parameters #
###############################
SERVER=$(hostname 2> $temp_log)
# get the server's FQDN
SENDER=$(host $SERVER 2> $temp_log)
# generate sender address for e-mail
USER=$(id -un 2>/dev/null)
if test $? -ne 0; then
    USER=$(id | cut -d "(" -f 2 | cut -d ")" -f 1)
fi


# Write log
$echo '____________________________________________________________\n' >> $temp_log
$echo "Starting zpoolbackup $(date +"%Y-%m-%d_%H:%M:%S") $DEBUGMSG ...\n" >> $temp_log

sec=$(date +%s) 				# initial time stamp
# If we don't have a date that implements +%s try to use python
if test "$sec" == "%s"; then
    sec=$(echo 'import time; print time.time()' 2>/dev/null | python)
    if test $? -eq 0; then
        use_python=1
    else
        sec="unknown"
    fi
fi    

if test "${SENDER%has*}" != "$SENDER"; then 
    SENDER=${USER}@${SENDER%has*}
else 
    unset EMAIL
    $echo "$runas: can't get my FQDN (host $SERVER failing), won't send e-mail.\n" | tee -a $temp_log 
fi

# check whether binaries exists
test ! $(which rsync 2>/dev/null) && critical "Can't find rsync." 
test ! $(which zfs 2>/dev/null) && critical "Can't find zfs." 

# check whether a given mountpoint exists
if test ! -z $BAKMOUNT; then
    test -d $BAKMOUNT || critical "$BAKMOUNT is not a valid mountpoint."
fi
# get mountpoint for $POOL
mountpoint=$(pfexec zfs list -H -o mountpoint "$POOL"  2>> $temp_log)
if test $? -ne 0; then
    critical "Cannot get mountpoint for $POOL"
fi

# mount; backup; configuration; umount
mounted=$(pfexec zfs list -H -o mounted $BAKPOOL 2>> $temp_log)
if test $? -ne 0; then
    critical "Cannot get mount information for $BAKPOOL. Please check whether this pool exists."
fi

backmountpoint=$(pfexec zfs list -H -o mountpoint "$BAKPOOL"  2>> $temp_log)
ec=$?

if test "$backmountpoint" != "legacy" && test ! -z "$BAKMOUNT" && test -z $FORCE; then
    critical "You specified legacy mountpoint $BAKMOUNT, but \n\t$BAKPOOL is to be zfs mounted on $backmountpoint. \n\tIf you wish to override the configured mountpoint please use -f."
fi

if test "$backmountpoint" == "legacy" && test -z "$BAKMOUNT"; then
    critical "$BAKPOOL is a legacy mount. Please specify mountpoint using -m."
fi

# backpool is mounted using zfs mount, but legacy mount point is forced
if test "$mounted" == "yes" && test "$backmountpoint" != "legacy" && test ! -z $FORCE && test $FORCE -eq 0; then
    echo pfexec zfs umount $BAKPOOL 2>> $temp_log 1>&2
    pfexec zfs umount $BAKPOOL 2>> $temp_log 1>&2
    test $? -ne 0 && critical "Can't zfs umount $BAKPOOL in order to re-mount it on $BAKMOUNT."
    echo pfexec zfs set mountpoint=legacy $BAKPOOL  2>> $temp_log 1>&2
    pfexec zfs set mountpoint=legacy $BAKPOOL  2>> $temp_log 1>&2
    mount_legacy "$BAKPOOL" "$BAKMOUNT"
fi

if test "$mounted" == "no"; then
    if test $ec -eq 0 && test "$backmountpoint" != "legacy" && test -z $FORCE; then
        echo pfexec zfs mount $BAKPOOL 2>> $temp_log 1>&2
        pfexec zfs mount $BAKPOOL 2>> $temp_log 1>&2
        if test $? -ne 0; then
            critical "Cannot mount $BAKPOOL using zfs mount. Check whether \nyou have permissions to use zfs mount. These can be gained using\nusermod -p 'ZFS File System Management' $USER"
        fi
    elif test ! -z $BAKMOUNT; then
        if test  ! -z $FORCE && test $FORCE -eq 0 && test "$backmountpoint" != "legacy"; then
            echo pfexec zfs set mountpoint=legacy $BAKPOOL  2>> $temp_log 1>&2
            pfexec zfs set mountpoint=legacy $BAKPOOL  2>> $temp_log 1>&2
        fi
    # try legacy mount
         mount | grep -w "$BAKMOUNT" >/dev/null 2>> $temp_log
         if test $? -eq 0; then
             mounted="yes"
         else
             mount_legacy "$BAKPOOL" "$BAKMOUNT"
         fi
    else
         critical "$BAKPOOL seems to be a legacy mount. \nPlease specify the legacy mountpoint using -m"
    fi
fi

if test ! -z "$backmountpoint" && test "$backmountpoint" != "legacy"; then
    if test -z $FORCE; then 
        backupdir=$backmountpoint
    else
        backupdir=$BAKMOUNT
    fi
else
    backupdir=$BAKMOUNT
fi

snapshot=$(date +"%Y-%m-%d_%H:%M:%S")
# temporary snapshot
test -z $DEBUGCMD && \
    echo  pfexec zfs snapshot -r ${POOL}@${snapshot}  2>> $temp_log 1>&2
$DEBUGCMD pfexec zfs snapshot -r ${POOL}@${snapshot}  2>> $temp_log 1>&2
if test $? -eq 0; then
    test -z $DEBUGCMD && \
        echo  rsync -avx --delete --exclude=zpool.cache $mountpoint/.zfs/snapshot/$snapshot/. $backupdir/. 2>> $temp_log 1>&2
    $DEBUGCMD rsync -avx --delete --exclude=zpool.cache $mountpoint/.zfs/snapshot/$snapshot/. $backupdir/. 2>> $temp_log 1>&2
    ec=$?
    if test $ec -eq 23; then
        critical "Failed to rsync $mountpoint snapshot $snapshot to $backupdir\nPlease check write permissions!\n\tPreserving snapshot ${POOL}@${snapshot}"
    elif test $ec -ne 0; then
        critical "Failed to rsync $mountpoint snapshot $snapshot to $backupdir\n\tPreserving snapshot ${POOL}@${snapshot}"
    elif test ! -z "${snapshot}"; then
        test -z $DEBUGCMD && \
            echo  pfexec zfs destroy -r ${POOL}@${snapshot} 2>> $temp_log 1>&2
        $DEBUGCMD pfexec zfs destroy -r ${POOL}@${snapshot} 2>> $temp_log 1>&2
        if test $? -ne 0; then
            warning "Failed to remove snapshot ${POOL}@${snapshot}"
        fi
    fi

else
    warning "Unable to create snapshot, trying to sync $mountpoint to $backupdir"
    $DEBUGCMD rsync -avx --delete --exclude=zpool.cache $mountpoint/. $backupdir/. 2>> $temp_log 1>&2
    if test $? -ne 0; then
        critical "Failed to rsync $mountpoint to $backupdir"
    fi
fi

for file in vfstab power.conf dumpadm.conf; do
    if test -f $backupdir/etc/$file; then
        sed -e "s%rpool%$BAKPOOL%g" $backupdir/etc/$file > $backupdir/etc/${file}.tmp 2>> $temp_log
        if test $? -ne 0; then
            critical "Failed to edit $backupdir/etc/$file"
        fi

        mv $backupdir/etc/${file}.tmp $backupdir/etc/${file}  2>> $temp_log 1>&2
        if test $? -ne 0; then
            critical "Failed to overwrite $backupdir/etc/${file} with edited copy"
        fi
    fi
done

# Unmount if the backup pool wasn't mounted initially
if test "$mounted" == "no"; then
    # unmounted zfs mount
    if test ! -z  "$backmountpoint" && test "$backmountpoint" != "legacy"; then
        if test -z $FORCE; then
            echo pfexec umount $BAKPOOL 2>> $temp_log 1>&2
            pfexec zfs umount $BAKPOOL 2>> $temp_log 1>&2
        else
           echo pfexec umount $BAKPOOL 2>> $temp_log 1>&2
           pfexec umount $BAKPOOL 2>> $temp_log 1>&2
            echo pfexec zfs set mountpoint=$backmountpoint $BAKPOOL  2>> $temp_log 1>&2
            pfexec zfs set mountpoint=$backmountpoint $BAKPOOL  2>> $temp_log 1>&2
            echo pfexec zfs umount $BAKPOOL 2>> $temp_log 1>&2
            pfexec zfs umount $BAKPOOL 2>> $temp_log 1>&2
        fi
    # unmounted legacy mount
    else
        echo pfexec umount $BAKPOOL 2>> $temp_log 1>&2
        pfexec umount $BAKPOOL 2>> $temp_log 1>&2
    fi
    test $? -ne 0 && critical "Failed to unmount $BAKPOOL"
else 
    # mounted zfs mount
    if test ! -z  "$backmountpoint" && test "$backmountpoint" != "legacy"; then
        if test ! -z $FORCE; then
            echo pfexec umount $BAKPOOL 2>> $temp_log 1>&2
            pfexec umount $BAKPOOL 2>> $temp_log 1>&2
            test $? -ne 0 && critical "Failed to unmount $BAKPOOL"
            echo pfexec zfs set mountpoint=$backmountpoint $BAKPOOL  2>> $temp_log 1>&2
            pfexec zfs set mountpoint=$backmountpoint $BAKPOOL  2>> $temp_log 1>&2
        fi
    fi
fi

# How long did it take (in seconds)?
if test $sec != "unknown"; then
    if test ! $use_python; then
        sec=$(($(date +%s) - sec))
    else
        sec=$(echo "import time; end=time.time(); print end - ${sec}" 2>/dev/null | python)
    fi
fi

# success
exit $exitstate
