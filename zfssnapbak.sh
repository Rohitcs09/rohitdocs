#! /bin/bash
#
# $Id: zfssnapbak.sh 45394 2009-09-21 08:21:09Z ahu $
#
# ==> Usage()
#
# date         who  vers   text
# 2015-Mar-12  pmo  3.4    if running in tty -> logging now also to $LOG
# 2014-May-28  pmo  3.3.2  Fixed daily snaps on dst if KEEPSNAPS_LOCAL configured
# 2014-May-22  pmo  3.3.1  Show times how log backup took last <days>
# 2014-May-19  pmo  3.3    performance improvement, number of snaps to preserve on source, remove FreeBSD support
# 2014-May-07  pmo  3.2.13 remove pidfile OnExit
# 2014-Mar-14  pmo  3.2.12 not setting any longer daily or weekly snapshots if in KEEPSNAPS configured 0
# 2014-Mar-10  pmo  3.2.12 fixed Backup zpool used percent in ec line output
# 2014-Mar-06  pmo  3.2.11 search for correct tac
# 2014-Mar-03  pmo  3.2.11 added option -c to check backup versions
# 2014-Feb-27  pmo  3.2.10 improved setting properties on snapshots, improved debug mode
# 2014-Feb-26  pmo  3.2.9  Performance improvements
# 2014-Feb-07  pmo  3.2.8  improved handling of removed filesystems on src
# 2014-Jan-23  pmo  3.2.7  added Backup zpool used percent to ec line
# 2014-Jan-16  pmo  3.2.6  GLOBAL_POSTACTION ntow after deleting old snapshots
# 2014-Jan-15  pmo  3.2.6  removed check if GLOBAL PRE/POST Action and PRE/POST Action is set
# 2013-Dez-16  pmo  3.2.6  CheckConfFile errors into logfile and not to stdout
# 2013-Nov-02  pmo  3.2.5  Performance improvements
# 2013-Okt-30  pmo  3.2.4  Prerequisite running zone to backup
# 2013-Okt-16  pmo  3.2.3  Prerequisite simple service to backup
# 2013-Jul-16  pmo  3.2.2  simpler lock file handling
# 2013-Jun-18  pmo  3.2.1  fixed critical bug where old snapshots was not deleted when RECURSIVE=0
# 2013-Jun-11  pmo  3.2    added global pre/post Actions
# 2013-Jun-11  pmo  3.1.6  added listing all remote snapshots with -l
# 2013-Mai-27  pmo  3.1.5  added PRE/POSTACTION for cdb online backup
# 2013-Mar-20  pmo  3.1.4  fixed initial sync if src snaps exists but no dst filesystem exists
# 2013-Mar-20  pmo  3.1.3  remove tmpfile OnExit correct
# 2013-Mar-15  pmo  3.1.2  if no dst filesystem sync all snaps
# 2013-Mar-06  pmo  3.1.1  bugfix - script hangs when filesystem could not be transfered
# 2013-Feb-21  pmo  3.1    Performance improvements
# 2013-Feb-20  pmo  3.0.4  lockfile now in /tmp
# 2013-Feb-15  pmo  3.0.3  Fixed error message "no such file or directory" when errors occurs
# 2013-Feb-14  pmo  3.0.2  Error message when already running as pid... in logfile and not to mail
# 2013-Feb-12  pmo  3.0.1  run snapbak only once a time, don't run parallel
# 2013-Jan-21  pmo  3.0    delete old snapshots rewritten, self healing implemented, be handling optimized
# 2013-Jan-14  pmo  2.3.1  fixed recursive transfering when more filesystems on dst as on src
# 2012-Dec-20  pmo  2.3    create only local snapshots, don't transfer them to BAKSRV
# 2012-Okt-11  pmo  2.2.6  fixed deletion of all snapshots and not only @$snappattern
# 2012-Okt-11  pmo  2.2.5  fixed snapattern to snappattern
# 2012-Sep-27  pmo  2.2.4  removed check if fs exists on $BAKSRV
# 2012-Sep-26  pmo  2.2.3  added: SG variable
# 2012-Sep-26  pmo  2.2.2  changed: now default ZFSRECVOPT=-x mountpoint
# 2012-Mar-30  pmo  2.2.1  added: "destroying..." at debug mode
# 2012-Mar-23  pmo  2.2	   added: recursive snapshoting/sending of snapshots; added: config option: RECURSIVE
# 2012-Mar-21  pmo  2.1    added: config option: ZFSSNAPOPT
# 2011-Nov-14  pmo  2.0.1  added: search for tail
# 2011-Sep-19  pmo  2.0	   added: configfile, timemachine like snapshots, pre/post actions, target fs parent, list all snapshots
# 2011-Apr-08  pmo  1.6.3  added mbuffer for FreeBSD to prevent an "broken pipe" when sending to gzip filesystem
# 2011-Apr-06  ahu  1.6.2  fixed a bug, where sub zfs of a given zfs where used as $latest
# 2011-Mar-02  pmo  1.6.1  improved grep "$snapattern" when searching for latest snapshot
# 2011-Feb-21  pmo  1.6	   added compatibility for freeBSD, improved deletion of old snapshots
# 2011-Feb-14  pmo  1.5.3  improved: find grep/date and some other improvements
# 2010-Dec-02  ahu  1.5.2  improved: zfs list commands
# 2010-Dec-02  pmo  1.5.1  improved: find latest snapshot
# 2010-Nov-24  ahu  1.5    added logfile
# 2010-Nov-17  ahu  1.4    added reset function and improved loops
# 2010-Nov-11  dk   1.3.1  changed ggrep to sfw
# 2010-Mar-15  ahu  1.3    improved snapshot handle
# 2010-Feb-04  ahu  1.2    changed to use options 
# 2009-Dec-15  ahu  1.1    keep snapshots and do more then one pool
# 2009-Dec-11  ahu  1.0    $prog_cmd introduced
  version="3.4"
copyright="(c..2009..2015, censhare AG, Munich)"
 suppmail="technik@censhare.de"
 progfile="$0"
 prog_cmd="${0##*/}";
 progname="${prog_cmd%%.*}"
  progdir="${0%/*}"

Error ()   { echo -e >&2 "$(date +'%Y%m%d-%H%M%S') $progname: $*"; exit 1; }
ConfErr () { echo -e >&2 "$(date +'%Y%m%d-%H%M%S') $progname: $*"; exit 6; }
Warning () { echo -e >&2 "$(date +'%Y%m%d-%H%M%S') $progname: $*"; }
Hint ()    { echo -e     "$(date +'%Y%m%d-%H%M%S') $progname: $*"; }

#################### Script parameter #################

# for config file
FSTOBAK=""				# zfs filesystems to backup
RECURSIVE="0"
ZFSSNAPOPT="$ZFSSNAPOPT"		# snapshot options
ZFSSENDOPT="$ZFSSENDOPT"		# zfs send options
ZFSRECVOPT="$ZFSRECVOPT -x mountpoint -o readonly=on"	# zfs recieve options
TRA_TO_BAKSRV="1"			# transfer to backup server
BAKSRV=""				# hostname of backup server
RECVPARENTFS=""
GLOBAL_PREACTION=""
GLOBAL_POSTACTION=""
PREACTION=""
POSTACTION=""
KEEPSNAPS="8h7d4w"
SG=""
SS=""
ZONE=""

# check for date, grep, sed, tail
for date in /usr/local/bin/date /usr/gnu/bin/date /bin/date /usr/bin/date notfound; do
    if test -x $date; then break; fi
done
if test $date = notfound; then Error "date not found."; fi
for grep in /usr/local/bin/grep /usr/bin/grep notfound; do
    if test -x $grep; then break; fi
done
if test $grep = notfound; then Error "grep not found."; fi
for sed in /usr/local/bin/sed /usr/bin/sed notfound; do
    if test -x $sed; then break; fi
done
if test $sed = notfound; then Error "sed not found."; fi
for tail in /usr/bin/tail notfound; do
    if test -x $tail; then break; fi
done
if test $tail = notfound; then Error "tail not found."; fi
for tac in /usr/local/bin/tac /usr/bin/tac notfound; do
    if test -x $tac; then break; fi
done
if test $tac = notfound; then Error "tac not found."; fi

LOG="/var/log/$progname.log"			# Log
snappattern="[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]-[0-9][0-9]:[0-9][0-9]"
currsnap="$($date +%Y.%m.%d-%H:%M)"
currsnap_hour="${currsnap##*-}"
currsnap_day="${currsnap%%-*}"
currsnap_week="$($date +%W)"
dbg=">/dev/null 2>&1"

#################### Functions #################

Include () {
    test -s $progdir/$1 && . $progdir/$1 && return 0
    Error "Include(): '$1' not avail or faulty."; 
}

export tmpfile=${TMP:-/tmp}/${progname%%.*}.$$
TmpfileExit () {
    rm $tmpfile $tmpfile.* 2>/dev/null
}

Tmp2Log () { cat $tmpfile 2>/dev/null >>$LOG; }

OnExit () {			# execute exit command list
    test -n "$exitlist" && eval "$exitlist"
    pidfile=/var/run/"$progname"_${conffile##*/}.pid
    rm $pidfile 2>/dev/null
}

OnExitAdd () {			# add "$@" to exit command list
    test -z "$exitlist" && exitlist=":"
    exitlist="$@; $exitlist"
    trap OnExit EXIT
}

OnExitAdd TmpfileExit;

InitSnap () {
    # PRE Action
    type PREACTION >/dev/null 2>&1 && {
    	FSTOBAK_VAR=${FS##*/}
    	Hint "running PREACTION for '$FS'"    	
	eval PREACTION "$FSTOBAK_VAR" "$dbg" || {
	    Warning "Error at: running PREACTION for '$FS'";
	    Hint "running POSTACTION for '$FS'"
	    eval POSTACTION "$FSTOBAK_VAR" "$dbg" || Error "Error at: running POSTACTION for '$FS'"
	    exit 1
	}
    }
    
    # initial create
    Hint "creating initial snapshot of '$FS'"
    zfs snapshot $ZFSSNAPOPT $FS@$currsnap || {
        Warning "Error creating snapshot on '$FS@currsnap'"
        Hint "running POSTACTION for '$FS'"
    	eval POSTACTION "$FSTOBAK_VAR" "$dbg" || Error "Error at: running POSTACTION for '$FS'";
	exit 1
    }
    
    # set zfs property
    for SNAP in $FSR; do
        zfs set $ZFSSNAPOPT backup:weekly="$currsnap_week" "$SNAP@$currsnap"
    done
    
    # POST Action
    type POSTACTION >/dev/null 2>&1 && {
	FSTOBAK_VAR=${FS##*/}
	Hint "running POSTACTION for '$FS'"
        eval POSTACTION "$FSTOBAK_VAR" "$dbg" || { 
            Error "Error at: running POSTACTION for '$FS'";
        }
    }
    
    # send first snapshot to backup host
    test "$TRA_TO_BAKSRV" = 1 && {
        Hint "sending first snapshot (can take a while)"    
	zfs send -p $ZFSSENDOPT $FS@$currsnap | $RECV_CMD zfs recv $ZFSRECVOPT $RECVPARENTFS$FS || {
   	    for SNAP in $FSR; do
                zfs destroy $SNAP@$currsnap >/dev/null 2>&1
                ssh $BAKSRV "zfs destroy $RECVPARENTFS$SNAP@$currsnap"
            done
            Error "Error sending '$FS' to '$RECVPARENTFS$FS' at '$BAKSRV' initially"
        }
    }
}

Sync () {
    test "$TRA_TO_BAKSRV" = 0 && Error "Option -s (sync) not available when TRA_TO_BAKSRV=1."
    for FS in $FSTOBAK; do
        test "$RECURSIVE" = "1" && {
            FSR=""
            for i in $(zfs list -r -H -o name -t filesystem "$FS"); do
                FSR="$FSR $i"
            done
        } || FSR=$FS
        for FS in $FSR; do
            local_destroy=""
            remote_destroy=""
            # check if fs exists on localhost
            zfs list -H -t filesystem "$FS" >/dev/null 2>&1 || {
                Warning "zfs filesystem '$FS' does not exist on localhost."
                continue
            }
            # check if fs exists on remote host
            eval ssh $BAKSRV 'zfs list -H -t filesystem $RECVPARENTFS$FS' >/dev/null 2>&1 || {
                Warning "zfs filesystem '$RECVPARENTFS$FS' does not exist on '$BAKSRV'."
                continue
            }
            local=$(zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "$FS" | $grep "$FS"@ | $tail -1)
            remote=$(eval ssh $BAKSRV 'zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily $RECVPARENTFS$FS | grep "$FS"@ | $tail -1')
	    local=${local##*@}
	    local=${local//./-}
	    local_h=${local##*-}
	    local_d=${local%-*}
	    remote=${remote##*@}
	    remote=${remote//./-}
	    remote_h=${remote##*-}
	    remote_d=${remote%-*}
	    local=$(eval $date -d \'$local_d $local_h\' +%s)
	    remote=$(eval $date -d \'$remote_d $remote_h\' +%s)
            test "$local" == "$remote" && {
                Hint "local and backup zfs snapshots of filesystem '$FS' locks the same, nothing to do."
                continue
            }
            test "$local" -gt "$remote" && {
                l=1
                while test :; do
	            local_snap=$(zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "$FS" | $grep "$FS"@ | $tail -"$l" | head -1)
	            if eval ssh $BAKSRV zfs get -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "$RECVPARENTFS$local_snap" >/dev/null 2>&1; then
	                break;
	            else
	                local_destroy="$local_destroy $local_snap"
	            fi
	            l=$[$l+1]
	        done
            }
            test "$local" -lt "$remote" && {
                l=1
                while test :; do
	            remote_snap=$(eval ssh $BAKSRV 'zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily $RECVPARENTFS$FS | grep "$FS"@ | $tail -$l | head -1')
	            if zfs get -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "${remote_snap/$RECVPARENTFS/}" >/dev/null 2>&1; then
	                break;
	            else
	                remote_destroy="$remote_destroy $remote_snap"
	            fi
	            l=$[$l+1]
	        done
            }
	    Hint "Following last 5 snapshots found on localhost:"
            zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "$FS" | $grep "$FS"@ | $tail -5
            Hint "Following last 5 snapshots found on '$BAKSRV':"
            eval ssh $BAKSRV zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily $RECVPARENTFS$FS | grep "$FS"@ | $tail -5
            test -n "$local_destroy" && {
                Hint "Listing snapshots to destroy on LOCALHOST:"
                for i in $local_destroy; do
	            echo "$i"
	        done
	        echo "Are your sure these snapshots should be destroyed on LOCALHOST? (y/n)"
	        read answer
	        test "$answer" = y && {
	            for i in $local_destroy; do
	                echo "Destroying on LOCALHOST: $i"
	                zfs destroy "$i";
	            done
	        }
	        unset answer
	    }
	    test -n "$remote_destroy" && {
	        Hint "Listing snapshots to destroy on REMOTEHOST '$BAKSRV':"
	        for i in $remote_destroy; do
	            echo "$i"
	        done
	        echo "Are your sure these snapshots should be destroyed on REMOTEHOST '$BAKSRV' (y/n)"
	        read answer
	        test "$answer" = y && {
	            for i in $remote_destroy; do
	                echo "Destroying on REMOTEHOST '$BAKSRV': $i"
	                ssh $BAKSRV "zfs destroy $i";
	            done
	        }
	        unset answer
	    }
        done
    done
}

List () {
    echo "Listing all local snapshots:"
    for FS in $FSTOBAK; do
        zfs list -H -t filesystem "$FS" >/dev/null 2>&1 || { 
            Warning "zfs filesystem '$FS' does not exist!"
            continue
        }
        echo "'$FS':"
        echo -e "\tHourly:"
        for i in $(zfs get -H -r -s local -o name backup:hourly "$FS"); do
            echo -e "\t\t$i"
        done
        echo -e "\t    Total: $(zfs get -H -r -s local backup:hourly "$FS" | wc -l)"
        echo -e "\tDaily:"
        for i in $(zfs get -H -r -s local -o name backup:daily "$FS"); do
            echo -e "\t\t$i"
        done
        echo -e "\t    Total: $(zfs get -H -r -s local backup:daily "$FS" | wc -l)"
        echo -e "\tWeekly:"
        for i in $(zfs get -H -r -s local -o name backup:weekly "$FS"); do
            echo -e "\t\t$i"
        done
        echo -e "\t    Total: $(zfs get -H -r -s local backup:weekly "$FS" | wc -l)"
    done
    test "$TRA_TO_BAKSRV" -eq 0 && exit 0
    echo -e "\n\n"
    echo "Listing all remote snapshots on dst '$BAKSRV':"
    # test if remote pool is imported - if not import it and export afterwards
    test -z ${RECVPARENTFS%%*/} && BAK_ZPOOL="${RECVPARENTFS%%/}"
    test -n "$RECVPARENTFS" && {
        ssh $BAKSRV "zpool list | grep $BAK_ZPOOL >/dev/null" || {
            Hint "Zpool '$BAK_ZPOOL' not imported at host '$BAKSRV'."
            echo -ne "$(date +'%Y%m%d-%H%M%S') $progname: Trying to import "; 
            while :; do
                echo -n ".";
                sleep 1;
            done & echo_pid=$!;
            disown $echo_pid
            if ssh $BAKSRV "zpool import $BAK_ZPOOL"; then
                kill $echo_pid
                echo "."
                Hint "Zpool '$BAK_ZPOOL' imported successfully at host '$BAKSRV'."
                ZPOOL_IMPORTED=true
            else
                kill $echo_pid
                echo "."
                Error "Can not import zpool '$BAK_ZPOOL' at host '$BAKSRV'."
            fi
        }
    }
    for FS in $FSTOBAK; do    
        ssh $BAKSRV zfs list -H -t filesystem "$RECVPARENTFS$FS" >/dev/null 2>&1 || { 
            Warning "zfs filesystem '$RECVPARENTFS$FS' on dst '$BAKSRV' does not exist!"
            continue
        }
        echo "'$RECVPARENTFS$FS':"
        echo -e "\tHourly:"
        for i in $(ssh $BAKSRV zfs get -H -r -s received -o name backup:hourly "$RECVPARENTFS$FS"); do
            echo -e "\t\t$i"
        done
        echo -e "\t    Total: $(ssh $BAKSRV zfs get -H -r -s received backup:hourly "$RECVPARENTFS$FS" | wc -l)"
        echo -e "\tDaily:"
        for i in $(ssh $BAKSRV zfs get -H -r -s received -o name backup:daily "$RECVPARENTFS$FS"); do
            echo -e "\t\t$i"
        done
        echo -e "\t    Total: $(ssh $BAKSRV zfs get -H -r -s received backup:daily "$RECVPARENTFS$FS" | wc -l)"
        echo -e "\tWeekly:"
        for i in $(ssh $BAKSRV zfs get -H -r -s received -o name backup:weekly "$RECVPARENTFS$FS"); do
            echo -e "\t\t$i"
        done
        echo -e "\t    Total: $(ssh $BAKSRV zfs get -H -r -s received backup:weekly "$RECVPARENTFS$FS" | wc -l)"
    done
    test -n "$ZPOOL_IMPORTED" && {
        Hint "Exporting '$BAK_ZPOOL' on host '$BAKSRV'."
        if ssh $BAKSRV "zpool export $BAK_ZPOOL"; then
            Hint "Exported '$BAK_ZPOOL' on host '$BAKSRV' successfully."
        else
            Error "Error exporting '$BAK_ZPOOL' on host '$BAKSRV'."
        fi
    }
    exit 0
}

Check () {
    echo "Listing all local snapshots:"
    for FS in $FSTOBAK; do
        zfs list -H -t filesystem "$FS" >/dev/null 2>&1 || { 
            Warning "zfs filesystem '$FS' does not exist!"
            continue
        }
        echo "'$FS':"
        echo -e "\tHourly:"
        for i in $(zfs list -H -r -t fs -o name "$FS"); do
            echo -e "\t\t$i \t\t$(zfs get -H -d 1 -r -s local -o name backup:hourly "$i" | wc -l)"
        done
        echo -e "\t    Total: \t\t\t$(zfs get -H -r -s local backup:hourly "$FS" | wc -l)"
        echo -e "\tDaily:"
        for i in $(zfs list -H -r -t fs -o name "$FS"); do
            echo -e "\t\t$i \t\t$(zfs get -H -d 1 -r -s local -o name backup:daily "$i" | wc -l)"
        done
        echo -e "\t    Total: \t\t\t$(zfs get -H -r -s local backup:daily "$FS" | wc -l)"
        echo -e "\tWeekly:"
        for i in $(zfs list -H -r -t fs -o name "$FS"); do
            echo -e "\t\t$i \t\t$(zfs get -H -d 1 -r -s local -o name backup:weekly "$i" | wc -l)"
        done
        echo -e "\t    Total: \t\t\t$(zfs get -H -r -s local backup:weekly "$FS" | wc -l)"
    done
    echo -e "\n"
    echo "Listing all remote snapshots on dst '$BAKSRV':"
    for FS in $FSTOBAK; do    
        ssh $BAKSRV zfs list -H -t filesystem "$RECVPARENTFS$FS" >/dev/null 2>&1 || { 
            Warning "zfs filesystem '$RECVPARENTFS$FS' on dst '$BAKSRV' does not exist!"
            continue
        }
        echo "'$RECVPARENTFS$FS':"
        echo -e "\tHourly:"
        for i in $(ssh $BAKSRV zfs list -H -r -t fs -o name "$RECVPARENTFS$FS"); do
            echo -e "\t\t$i \t\t$(ssh $BAKSRV zfs get -H -d 1 -r -s received -o name backup:hourly $i | wc -l)"
        done
        echo -e "\t    Total: \t\t\t\t$(ssh $BAKSRV zfs get -H -r -s received backup:hourly "$RECVPARENTFS$FS" | wc -l)"
        echo -e "\tDaily:"
        for i in $(ssh $BAKSRV zfs list -H -r -t fs -o name "$RECVPARENTFS$FS"); do
            echo -e "\t\t$i \t\t$(ssh $BAKSRV zfs get -H -d 1 -r -s received -o name backup:daily $i | wc -l)"
        done
        echo -e "\t    Total: \t\t\t\t$(ssh $BAKSRV zfs get -H -r -s received backup:daily "$RECVPARENTFS$FS" | wc -l)"
        echo -e "\tWeekly:"
        for i in $(ssh $BAKSRV zfs list -H -r -t fs -o name "$RECVPARENTFS$FS"); do
            echo -e "\t\t$i \t\t$(ssh $BAKSRV zfs get -H -d 1 -r -s received -o name backup:weekly $i | wc -l)"
        done
        echo -e "\t    Total: \t\t\t\t$(ssh $BAKSRV zfs get -H -r -s received backup:weekly "$RECVPARENTFS$FS" | wc -l)"
    done
    exit 0
}

# simple configuration file handling

# if no config file was defined on the command line, use the default:
test -z $conffile && conffile=${HOME%/}/.${progname%%.*}.rc  

WriteConfFile ()					# write default configuration
{
    cat <<-EOF >$conffile || Error "configfile '$conffile' can not be created."
	# zfssnapbak v3
	# automatically generated by $progname at $($date +%Y.%m.%d-%H:%M)

	# logfile
	# default: LOG="$LOG"
	LOG="$LOG"

	# Keep number of snapshots on source side
	# 0 = Keep all snapshots as on destination
	# default: KEEPSNAPS_LOCAL="0"
	KEEPSNAPS_LOCAL="0"
	
	# Keep number of snapshots
	# h = Versions of Hourly Backups to keep
	# d = Versions of Daily Backups to keep
	# w = Versions of Weekly Backups to keep
	# default: KEEPSNAPS="$KEEPSNAPS"
	# 8 Versions per hours, 7 Versions per days, 4 Versions per weeks
	KEEPSNAPS="$KEEPSNAPS"
	
	# which local zone must be up and running as a prerequisite for this script?
	ZONE=""
	
	# which s2s simple service must be up and running as a prerequisite for
	# this script? (leave blank if you don't use s2s)
	# SS="censhare"
	SS=""
	
	# which s2s service group must be up and running as a prerequisite for 
	# this script? (leave blank if you don't use s2s)
	# SG="ora"
	SG=""

	# GLOBAL PRE/POST actions
	# Would be executed before and after snapshoting, send/receiving and syncing
	# Uncomment one of the following examples if necessary:
	# Oracle online Backup by 'begin backup, end backup, backup controlfile to of a zone'
	#   Note: '\047' is used to create an single quote to ensure echo don't do anything wrong; see echo manual for more details
	#   please change the zonename $ZONE twice!
	#   GLOBAL_PREACTION () { zlogin $ZONE 'su - oracle -c "echo -e \"connect / as sysdba;\nwhenever sqlerror exit sql.sqlcode;\nalter system archive log current;\nalter database begin backup;\nquit;\" | sqlplus /nolog"'; }
	#   GLOBAL_POSTACTION () { zlogin $ZONE 'su - oracle -c "echo -e \"connect / as sysdba;\nwhenever sqlerror exit sql.sqlcode;\nalter database end backup;\nalter database backup controlfile to \047/censhare/oracle/control.sql\047 reuse;\nquit;\" | sqlplus /nolog"'; }

	# GLOBAL_PREACTION() {}
	# GLOBAL_POSTACTION() {}
        
	# PRE/POST actions for every backuped zfs filesystem.
	# Would be executed before and after snapshoting the source fs.
	# If you want to do something within a zone, please use '\$1'. Example: 'zlogin \$1'.
	# '\$1' would be replaced by the zone name.
	# The last part of the zfs fs will be used as the zone name:
	#    zfs fs name: 'censhare/tracker-css'
	#      -> zone name should be 'tracker-css'
	#      -> '\$1' would be replaced by 'tracker-css'    
	# Uncomment one of the following examples if necessary:
	# Oracle online Backup by 'begin backup, end backup, backup controlfile to of a zone'
	#   Note: '\047' is used to create an single quote to ensure echo don't do anything wrong; see echo manual for more details
	#   PREACTION () { zlogin \$1 'su - oracle -c "echo -e \"connect / as sysdba;\nwhenever sqlerror exit sql.sqlcode;\nalter system archive log current;\nalter database begin backup;\nquit;\" | sqlplus /nolog"'; }
	#   POSTACTION () { zlogin \$1 'su - oracle -c "echo -e \"connect / as sysdba;\nwhenever sqlerror exit sql.sqlcode;\nalter database end backup;\nalter database backup controlfile to \047/censhare/oracle/control.sql\047 reuse;\nquit;\" | sqlplus /nolog"'; }
	#
	# Oracle online Backup by 'begin backup, end backup, backup controlfile to of a local installation'
	#   PREACTION () { su - oracle -c "echo -e \"connect / as sysdba;\nwhenever sqlerror exit sql.sqlcode;\nalter system archive log current;\nalter database begin backup;\nalter database backup controlfile to \047/opt/oracle/control.sql\047 reuse;\nquit;\" | sqlplus /nolog"; }
	#   POSTACTION () { su - oracle -c "echo -e \"connect / as sysdba;\nwhenever sqlerror exit sql.sqlcode;\nalter database end backup;\nquit;\" | sqlplus /nolog"; }
	#
	# corpus online backup including cdb by 'kill -STOP <censhare-pid>; kill -CONT <censhare-pid>;' for Solaris 10
	#  please change $CSS_ID to censhare Server CSS_ID twice!
	#   PREACTION () { kill -STOP \$(set -- \$(/usr/ucb/ps -auxww | grep "[c]om.censhare.server.kernel.CenShareServer \$CSS_ID initial"); echo \$2) || ec=\$?; }
	#   POSTACTION () { kill -CONT \$(set -- \$(/usr/ucb/ps -auxww | grep "[c]om.censhare.server.kernel.CenShareServer \$CSS_ID initial"); echo \$2) || ec=\$?; }
	# corpus online backup including cdb by 'kill -STOP <censhare-pid>; kill -CONT <censhare-pid>;' for Solaris 11
	#  please change $CSS_ID to censhare Server CSS_ID twice!
	#   PREACTION () { kill -STOP \$(set -- \$(/usr/bin/ps auxww | grep "[c]om.censhare.server.kernel.CenShareServer \$CSS_ID initial"); echo \$2) || ec=\$?; }
	#   POSTACTION () { kill -CONT \$(set -- \$(/usr/bin/ps auxww | grep "[c]om.censhare.server.kernel.CenShareServer \$CSS_ID initial"); echo \$2) || ec=\$?; }
	
	# PREACTION() {}
	# POSTACTION() {}

	# zfs filesystems to backup
	# White-space separated list
	FSTOBAK="$FSTOBAK"
	
	# transfer snapshots to BAKSRV 0=no 1=yes
	# default TRA_TO_BAKSRV=1
	# if set to 0 -> following variables will be ignored:
	#     BAKSRV, RECVPARENTFS, ZFSSENDOPT, ZFSRECVOPT
	TRA_TO_BAKSRV="$TRA_TO_BAKSRV"
		
	# Backup host
	BAKSRV="$BAKSRV"
	
	# zfs destination parent filesystem
	RECVPARENTFS="$RECVPARENTFS"
	
	# recursively create and send snapshots: 0=no 1=yes
	# set to 1 if backing up Solaris 11.* zones
	# default RECURSIVE="0"
	RECURSIVE="$RECURSIVE"
	
	# zfs snapshot options
	ZFSSNAPOPT="$ZFSSNAPOPT"
	# zfs send options
	ZFSSENDOPT="$ZFSSENDOPT"
	# zfs recv options
	ZFSRECVOPT="$ZFSRECVOPT"
	

EOF

}

ReadConfFile ()						# read configuration
{
    test -z "$conffile" && return			# no config file => no action
    if test -f $conffile; then				# config file avail?
        confheadversion=$(head -1 $conffile)
        test "$confheadversion" = "# zfssnapbak v2" && Error "Error: $progname = Version 3. Conffile '$conffile' is on Version 2. Please recreate the backup completely and update the configuration file if necessary."
	if /bin/bash <$conffile >&/dev/null; then	#     sourcing wo error?
	    . $conffile					#         then doit
	    return					#         and return
	else						#     problems in config
	    Error "Syntax error in configuration file '$conffile'."
	fi						#
    else						# write default config file and exit
	WriteConfFile
	Error "Please edit the configuration file \n'$conffile' as required and re-run.\n\nIf this error message sounds unexpected, please check whether you specified\nthe configuration file to use with -f. "
    fi
}

CheckConfFile () {
    # check if filesystems to backup is set
    test -z "$FSTOBAK" && Error "No zfs filesystems to backup set. Check configuration file '$conffile'."
    # check if logfile is set
    test -z "$LOG" && Error "Logfile not set. Check configuration file '$conffile'."
    # check if KEEPSNAPS_LOCAL is set correct
    test "$KEEPSNAPS_LOCAL" -eq "$KEEPSNAPS_LOCAL" 2>/dev/null || Error "'KEEPSNAPS_LOCAL' '$KEEPSNAPS_LOCAL' not set correct. Not a number."
    # check if KEEPSNAPS_LOCAL not equal 0 and TRA_TO_BAKSRV is set to 0
    test "$TRA_TO_BAKSRV" -eq 0 && {
        test "$KEEPSNAPS_LOCAL" -eq 0 || Error "'TRA_TO_BAKSRV' is set to '$TRA_TO_BAKSRV' and 'KEEPSNAPS_LOCAL' is set to '$KEEPSNAPS_LOCAL'. KEEPSNAPS_LOCAL should be 0."
    }
    # check if KEEPSNAPS is set correct 
    test -z "${KEEPSNAPS/[0-9]*h[0-9]*d[0-9]*w/}" || Error "'KEEPSNAPS' '$KEEPSNAPS' not set correct. Format: [0-9]h[0-9]d[0-9]w. Check configuration file '$conffile'."
    # check if SS and SG are not both set
    test -n "$SG" -a -n "$SS" && Error "Backup prerequisite SG '$SG' and SS '$SS' both set in config file '$conffile' - please set only one."
    # check if TRA_TO_BAKSRV is set correct
    test "$TRA_TO_BAKSRV" = 1 -o "$TRA_TO_BAKSRV" = 0 || Error "'TRA_TO_BAKSRV' '$TRA_TO_BAKSRV' not set correct. '0' or '1' possible."
    # check if BAKSRV is set
    test "$TRA_TO_BAKSRV" = 1 && {
        test -z "$BAKSRV" && Error "'BAKSRV' not set. Check configuration file '$conffile'."
    }
    test "$TRA_TO_BAKSRV" = 1 && {
        ssh -o StrictHostKeyChecking=no -o BatchMode=yes $BAKSRV pwd >&/dev/null || Error "Cannot connect to host '$BAKSRV' via ssh without user interaction.\nCheck manually 'ssh $BAKSRV pwd'."
    }
    # set RECVPARENTFS correct
    test -z ${RECVPARENTFS%%*/} || RECVPARENTFS="$RECVPARENTFS/"
    # remove ssh if BAKSRV=localhost
    if test "$BAKSRV" = "localhost"; then
        RECV_CMD=""
    else
        RECV_CMD="ssh $BAKSRV"
    fi
}

BackupTimes () {
    timeframe="$1"
    # Check if timeframe is given correct
    echo "Time needed in seconds for backup"
    test "$timeframe" -eq "$timeframe" || Error "Timeframe '$timeframe' not set correct. Not a number."
    timeframe=$[$timeframe+1]
    counter=1
    date_timeframe=$(while test $counter -ne $timeframe; do
        $date --date="-$counter days" +'%d.%m.%Y'
        counter=$[$counter+1]
    done | tac)
    hashes () {
        tmp='#';
        while [ ${#tmp} -lt $1 ]; do
            tmp=$tmp$tmp$tmp;
        done;
        echo -n ${tmp:0:$1}
    }
    sum=0;
    for day in $date_timeframe; do
        for hash in $(sed -n "/\#\#\#\ exit\ ec=successfully\ at\ .*$day/ { s/.*time:\ //; s/s.*//p; }" $LOG | while read num; do
            sum=$(($sum + $num));
            echo $sum;
        done | tail -1); do
            timed=${day%%.*}
            timem=${day#*.}
            timem=${timem%%.*}
            timey=${day##*.}
            echo -n "  $day - $($date -d "$timey"-"$timem"-"$timed" +%a): "
            hashes $(( $hash / 100))
            echo " "$hash"s"
        done
    done;
exit
}

Lock () {
    pidfile=/var/run/"$progname"_${conffile##*/}.pid
    test -e "$pidfile" && {
        pid=$(cat "$pidfile")
        if kill -0 & >1 > /dev/null $pid; then
            Error "Already running as pid '$pid'."
        else
            rm "$pidfile"
        fi
    }
    echo $$ > "$pidfile"
}

################### Usage #############################

Usage () {
    cat <<EOF
$progname: Version $version, $copyright

NAME
    $progname - Backups zfs filesystem via snapshots to a remote host

SYNOPSIS
    $progname [options] {args...}

DESCRIPTION
    creates a snapshot of a zfs filesystem and copies it to another zfs filesystem on '$BAKSRV'
    if initially transferd, the snaphost is going to be transfert incremental.
    If something goes wrong, the next time the script will be executed it tries to fix itself.
    Only if there is a newer snapshot on the destination as on the source, an Error will occur.
    
OPTIONS
    -f <file>   Defines the configuration file to use. 
                Default for this user on this host: 
                  '${HOME%/}/.${progname%%.*}.rc'
    -l          Lists all backups including snapshots managed by $progname
    -c          Lists all backups managed by $progname and count snapshots
    -s		Synchronize local and remote snapshots
    -d		Debug mode for PRE/POST actions and snapshot deletions
    -t <days back>
    		Show times how log backup took last <days>

    -v      Version
    -h      Help

REQUIREMENTS
    Password free ssh login to $BAKSRV
    zfs filesystem '$FS' has to exist on localhost and on '$BAKSRV'
    Supported Systems: Solaris 10, Solaris 11.1

HINTS
    If a backuped Solaris 11 zone will be moved to another host, the backup needs to be recreated.
    Otherwise you will get an error like:
      "Error: snapshots on 'fs' exists but no snapshots on '$BAKSRV', clean manually - skipping transfer..."
    This can be done by renaming the backup filesystem and rerunning the backup script.
    
CONFIGURATION VARIABLES
    LOG		  Log file (including absolute path). Not used when $progname
        	  is run from the commandline
    KEEPSNAPS_LOCAL
                  Keep number of snapshots on source. If set to 0 all snapshots as
                  on destination will be preserved. Only available if TRA_TO_BAKSRV=1
    KEEPSNAPS 	  Keep number of snapshots.
		  h = Versions of Hourly Backups to keep
		  d = Versions of Daily Backups to keep
		  w = Versions of Weekly Backup to keep
    ZONE          The local zone that must run on the production host prior to the backup.
    SS		  The simple service that must run on the production host
    		  prior to the backup. Applies only to environments using s2s
    SG		  The service group that must run on the production
    		  host prior to the backup. Applies only environments using s2s
    GLOBAL_PREACTION/GLOBAL_POSTACTION
                  Functions that should be executed before and after
                  snapshoting, send/receiving and syncing.
    PREACTION/POSTACTION
    		  Functions that should be executed before and after snapshoting the source fs.
		  If you want to do something within a zone please use '\$1' example: 'zlogin \$1'.
		  '\$1' would be replaced by the zone name.
    		  The last part of the zfs fs will be used as the zone name:
    		    zfs fs name: 'censhare/tracker-css'
    		      -> zone name should be 'tracker-css'
    		      -> '\$1' would be replaced by 'tracker-css'    		  
    FSTOBAK   	  zfs filesystems to backup. White-space separated list
    TRA_TO_BAKSRV transfer snapshots to BAKSRV 0=no 1=yes
                  if set to 0 (no) only local snapshots will be created 
                  and the following variables will be ignored:
                      BAKSRV, RECVPARENTFS, ZFSSENDOPT, ZFSRECVOPT
    BAKSRV     	  the remote backup host
    RECVPARENTFS  zfs destination parent filesystem
    RECURSIVE     recursively create and send snapshots: 0=no 1=yes
    ZFSSNAPOPT	  zfs snapshot options
    ZFSSENDOPT	  zfs send options
    ZFSRECVOPT	  zfs recv options

FILES
    '$conffile'   configuration file 
                  (might be changed using the -f option)
    '$LOG'	  Logfile

SEE ALSO
    zfs(1), ssh(1), sshd(8) 
    
AUTHORS
    Andreas Hubert, censhare AG, Munich
    Patrick Molnar, censhare AG, Munich

BUGS
    Needs bash(1), developed with bash-3.1.16(1).
    Send bugreports to $suppmail and add version info.

$copyright
EOF
    exit 0
}

#################### Commandline ######################
OPTERR=0                                # suppress error messages
OPTIND=1
while getopts ":vhslcdf:t:" opt "$@"; do
    case $opt in
        s)  ReadConfFile; CheckConfFile; Sync; exit;;
        l)  ReadConfFile; CheckConfFile; List;;
        d)  dbg="";;
        c)  ReadConfFile; CheckConfFile; Check;;
        f)  conffile="$OPTARG" ;;
        t)  ReadConfFile; CheckConfFile; BackupTimes "$OPTARG";;
        v)  echo "$progname, version $version"; exit;;
        h)  Usage;;
        *)  Error "unknown option or missing arg at '-$OPTARG'.";;
    esac
done
shift $((OPTIND-1))                     # remove option from commandline
#test -z "$1" && Error "args missing."
#################### And action ;-) ###################
ReadConfFile

test -n "$SG" -o -n "$SS" && {
    s2s_status=$(/usr/bin/s2s -p status $SG $SS 2>&1); ec_s2s=$?
    test $ec_s2s -eq 0 || {
    	tty >&/dev/null && Error "$s2s_status"
    	exit 1
    }
}

test -n "$ZONE" && {
    set -- $(zoneadm -z $ZONE list -v 2>/dev/null | tail -1)
    test "$3" == running || {
        tty >&/dev/null && Error "Local zone '$ZONE' not up and running - please check via 'zoneadm -z $ZONE list -v'."
        exit 1
    }
}

OnExitAdd Tmp2Log;                          #     prep redirect output to log
exec 3>&1                                   #     save current output channel

{
sec=$($date +%s)				# init time measurement
exec 2>&1
! tty >&/dev/null && exec >$tmpfile 2>&1
(
exec 3<&-;					# close filehandle 3
ec=0; anyerr=0; 
echo "### -----------------------------------------------------------------------"
echo "### Start '$progname' am '$($date +"%d.%m.%Y (%a), um %H:%M:%S")'"
echo "### -----------------------------------------------------------------------"
CheckConfFile
Lock

# check for recursive
test "$RECURSIVE" = "1" && {
    ZFSSNAPOPT="-r $ZFSSNAPOPT"
    ZFSSENDOPT="-r $ZFSSENDOPT"
}

# Global PRE Action
type GLOBAL_PREACTION >/dev/null 2>&1 && {
    Hint "running GLOBAL_PREACTION"
    eval GLOBAL_PREACTION "$dbg" || {
        Warning "Error at: running GLOBAL_PREACTION";
        Hint "running GLOBAL_POSTACTION"
        eval GLOBAL_POSTACTION "$dbg" || Error "Error at: running GLOBAL_POSTACTION"
        exit 1
    }
}

for FS in $FSTOBAK; do
    # if recursive set FSR
    test "$RECURSIVE" = "1" && {
        FSR=""
        for i in $(zfs list -r -H -o name -t filesystem "$FS"); do
            FSR="$FSR $i"
        done
    } || FSR=$FS
    # check if fs exists on localhost
    if ! zfs list -H -t filesystem "$FS" >/dev/null 2>&1
        then Warning "zfs '$FS' does not exist, please create it"
        anyerr=1
        continue
    fi
    # check if snapshots exists
    test "$TRA_TO_BAKSRV" = 1 && {
        newest_local="$(zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "$FS" 2>/dev/null | $grep "$FS@$snappattern$" | $tail -1)"
        if test -z "$newest_local"; then
            InitSnap || anyerr=1
            continue
        fi
        test "$RECURSIVE" = "1" && {
            test -n "$newest_local" && {
                $RECV_CMD zfs list $RECVPARENTFS$FS >/dev/null 2>&1 || {
                    Warning "Snapshots on src '$FS' exists but no filesystem on '$BAKSRV', trying to sync all src snaps to dst."
                    if ! zfs send -p -R $newest_local | $RECV_CMD zfs recv $ZFSRECVOPT $RECVPARENTFS$FS; then
                        Error "Error trying to sync all src snaps to dst."
                        anyerr=1
                    else
                        Hint "Synced all src snaps to dst successfully"
                    fi
                    continue
                }
            }
        }
    }
  
    # find latest snapshot
    latest=$(zfs get -d 1 -H -r -s local -o name backup:hourly,backup:weekly,backup:daily "$FS" | $grep "$FS@$snappattern$" | $tail -1)

    # PRE Action for every backuped filesystem
    type PREACTION >/dev/null 2>&1 && {
    	FSTOBAK_VAR=${FS##*/}
    	Hint "running PREACTION for '$FS'"
	eval PREACTION "$FSTOBAK_VAR" "$dbg" || {
	    Warning "Error at: running PREACTION for '$FS'";
	    Hint "running POSTACTION for '$FS'"
	    eval POSTACTION "$FSTOBAK_VAR" "$dbg" || Warning "Error at: running POSTACTION for '$FS'"
	    anyerr=1
	    continue
	}
    }

    # create snapshot for incremental backup 
    Hint "creating incremental snapshot of '$FS'"
    if ! zfs snapshot $ZFSSNAPOPT $FS@$currsnap; then
        Warning "Error creating snapshot for incremental '$FS@$currsnap'"
        type POSTACTION >/dev/null 2>&1 && {
            FSTOBAK_VAR=${FS##*/}
            Hint "running POSTACTION for '$FS'"
            eval POSTACTION "$FSTOBAK_VAR" "$dbg" || {
                Warning "Error at: running POSTACTION for '$FS'"
                anyerr=1
                continue
            }
        }
        anyerr=1
        continue
    fi
        
    # POST Action for every backuped filesystem
    type POSTACTION >/dev/null 2>&1 && {
	FSTOBAK_VAR=${FS##*/}
	Hint "running POSTACTION for '$FS'"
        eval POSTACTION "$FSTOBAK_VAR" "$dbg" || { 
            Warning "Error at: running POSTACTION for '$FS'";
            for SNAP in $FSR; do
                zfs destroy $SNAP@$currsnap
            done
            anyerr=1
            continue
        }
    }
    
    # set zfs properties
    set_zfs_props () {
        based_on="$1"
        test "$based_on" = "based_on_local" && {
            remote=""
            RECV_PARENTFS=""
        }
        test "$based_on" = "based_on_remote" && {
            remote="$RECV_CMD"
            RECV_PARENTFS="$RECVPARENTFS"
        }
        KEEPSNAPS_d="${KEEPSNAPS##*h}"
        KEEPSNAPS_d="${KEEPSNAPS_d%%d*}"
        KEEPSNAPS_w="${KEEPSNAPS##*d}"
        KEEPSNAPS_w="${KEEPSNAPS_w%%w*}"
        for SNAP in $FSR; do
            if test "$($remote zfs get -H -r -s local,received -o value backup:weekly $RECV_PARENTFS$SNAP | $tail -1)" != "$currsnap_week" -a "$KEEPSNAPS_w" -ne 0; then
                test -z "$dbg" && Hint "Setting prop 'backup:weekly' on '$SNAP@$currsnap'."
                zfs set backup:weekly="$currsnap_week" "$SNAP@$currsnap"
            else
                if test $($remote zfs get -H -r -s local,received -o name backup:daily $RECV_PARENTFS$SNAP | $grep "@$currsnap_day" | wc -l) = 0 -a "$KEEPSNAPS_d" -ne 0; then
                    test -z "$dbg" && Hint "Setting prop 'backup:daily' on '$SNAP@$currsnap'."
                    zfs set backup:daily="$currsnap_day" "$SNAP@$currsnap"
                else
                    test -z "$dbg" && Hint "Setting prop 'backup:hourly' on '$SNAP@$currsnap'."
                    zfs set backup:hourly="$currsnap_hour" "$SNAP@$currsnap"
                fi
            fi
        done
    }
    
    if test "$KEEPSNAPS_LOCAL" -eq 0; then
        set_zfs_props based_on_local
    else
        set_zfs_props based_on_remote
    fi
    
    # only if TRA_TO_BAKSRV = 1 and RECURSIVE = 1
    test "$TRA_TO_BAKSRV" = 1 && {
        test "$RECURSIVE" = 1 && {
            # save fs on BAKSRV which are not at src
            for FS_SYNC in $($RECV_CMD zfs list -r -t filesystem -o name -H $RECVPARENTFS$FS); do
                test -n "$RECVPARENTFS" && FS_SYNC="${FS_SYNC/$RECVPARENTFS/}"
                zfs list $FS_SYNC >/dev/null 2>&1 || {
                    FS_RENAME=${FS_SYNC/$FS\//}
                    Hint "saving '$RECVPARENTFS$FS_SYNC' to '"$RECVPARENTFS$FS"-zfssnapbak/$FS_RENAME'"
                    $RECV_CMD zfs rename -p $RECVPARENTFS$FS_SYNC "$RECVPARENTFS$FS"-zfssnapbak/$FS_RENAME 2>/dev/null
                    $RECV_CMD zfs set backup:saved-at="$currsnap" "$RECVPARENTFS$FS"-zfssnapbak/$FS_RENAME
                }
            done
    # sync src and dest snapshots and send incremental snapshot to remote host    
        # for all recursive filesystems do
        for FS_SYNC in $(zfs list -r -t filesystem -o name -H $FS); do
            # if no snapshot on destination
            $RECV_CMD zfs list -d 1 -r -t snapshot -o name -H $RECVPARENTFS$FS_SYNC 2>/dev/null | grep "@$snappattern$" >/dev/null 2>&1 || {
                # and more 1 snapshot on src
                if test "$(zfs list -d 1 -r -t snapshot -o name -H $FS_SYNC 2>/dev/null | grep "@$snappattern$" | wc -l)" -ge 2; then
                    # Error Message and break this backup
                    Error "Error: snapshots on '$FS_SYNC' exists but no snapshots on '$BAKSRV', clean manually - skipping transfer..."
                    anyerr=1
                    continue 2
                else
                    # only break the fs sync procedure
                    continue
                fi
            }
            # check if remote snapshots newer then local
            latest_remote_snap=$($RECV_CMD zfs list -d 1 -r -t snapshot -o name -H $RECVPARENTFS$FS_SYNC 2>/dev/null | grep "@$snappattern$" | $tail -1)
            latest_remote_snap="${latest_remote_snap/$RECVPARENTFS/}"
            zfs list -r -t snapshot -o name -H $latest_remote_snap >/dev/null 2>&1 || {
                Error "Error: Remote snapshot '$RECVPARENTFS$latest_remote_snap' on host '$BAKSRV' newer then local. Please check manually."
                anyerr=1
                break 2
            }
            tail_number="-2"
            while :; do
                sync_snap=$(zfs list -d 1 -r -t snapshot -o name -H $FS_SYNC | grep "@$snappattern$" | $tail $tail_number | head -1)
                # if last snapshot not on destination do incremental transfer to fix
                if $RECV_CMD zfs list -r -t snapshot $RECVPARENTFS$sync_snap >/dev/null 2>&1; then
                    if test "$tail_number" = -2; then
                        break
                    else
                        # transfer all snaps which are missing on dst
                        Warning "Warning: Snapshots from '$sync_snap' to '$FS_SYNC@$currsnap' are missing on '$BAKSRV'. Resending."
                        zfs send -p -I $sync_snap $FS_SYNC@$currsnap | $RECV_CMD zfs recv $ZFSRECVOPT $RECVPARENTFS$FS_SYNC || {
                            Error "Error at: resending incremental snapshots from '$sync_snap' to '$FS_SYNC@$currsnap' to host '$BAKSRV'."
                            anyerr=1
                        }
                        break
                    fi
                else
                    tail_number=$[$tail_number-1]
                    continue
                fi
            done
        done
        }
    }
    # send incremental snapshot to remote host
    test "$TRA_TO_BAKSRV" = 1 && {
        if ! zfs send -p $ZFSSENDOPT -i $latest $FS@$currsnap | $RECV_CMD zfs recv $ZFSRECVOPT $RECVPARENTFS$FS; then
            for SNAP in $FSR; do
                zfs destroy $SNAP@$currsnap
                ssh $BAKSRV "zfs destroy $RECVPARENTFS$SNAP@$currsnap"
            done
            Warning "Error sending incremental fs to '$BAKSRV'"
            type POSTACTION >/dev/null 2>&1 && {
                FSTOBAK_VAR=${FS##*/}
                Hint "running POSTACTION for '$FS'"
                eval POSTACTION "$FSTOBAK_VAR" "$dbg" || {
                    Warning "Error at: running POSTACTION for '$FS'"
                    anyerr=1
                    continue
                }
            }
            anyerr=1
    	    continue
        else
            Hint "Transfered '$FS' successfully"
        fi
    }
done
for FS in $FSTOBAK; do    
    # prepare KEEPSNAPS vars for destroying old snapshots
    KEEPSNAPS_h="${KEEPSNAPS%%h*}"
    KEEPSNAPS_d="${KEEPSNAPS##*h}"
    KEEPSNAPS_d="${KEEPSNAPS_d%%d*}"
    KEEPSNAPS_w="${KEEPSNAPS##*d}"
    KEEPSNAPS_w="${KEEPSNAPS_w%%w*}"
    
    destroy_saved_fs () {
        KEEPSNAPS=$1
        VERSION=$2
	loldest_snap=$(zfs get -d 1 -H -r -s local -o name backup:$VERSION "$FS" | head -1)
        loldest_snap=${loldest_snap##*@}
    	version_count=$(zfs get -d 1 -H -r -s local -o name backup:$VERSION "$FS" | wc -l)
        test "$version_count" -ge "$KEEPSNAPS" && {
    	    tsaved=${saved_fs_time##*@}
    	    tsaved=${tsaved//./-}
    	    tsaved_h=${tsaved##*-}
    	    tsaved_d=${tsaved%-*}
    	    tlocal=${loldest_snap##*@}
    	    tlocal=${tlocal//./-}
    	    tlocal_h=${tlocal##*-}
    	    tlocal_d=${tlocal%-*}
    	    tlocal=$(eval $date -d \'$tlocal_d $tlocal_h\' +%s)
    	    tsaved=$(eval $date -d \'$tsaved_d $tsaved_h\' +%s)
    	    test "$tlocal" -gt "$tsaved" && {
    	        Hint "destroying '$destroy_saved' on host '$BAKSRV'."
    	        $RECV_CMD zfs destroy -r "$destroy_saved"
    	    }
    	}
    }
    
    # destroy old saved filesystems at backup fs
    for destroy_saved in $($RECV_CMD zfs list -r -H -o name -t filesystem "$RECVPARENTFS$FS-zfssnapbak" 2>/dev/null | $tac); do
        saved_fs_time=$($RECV_CMD zfs get -H -o value backup:saved-at $destroy_saved 2>/dev/null) && {
            [[ $saved_fs_time =~ [0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9] ]] || continue
    	    if test "$KEEPSNAPS_w" -gt 0; then
    	        destroy_saved_fs "$KEEPSNAPS_w" "weekly"
    	    elif test "$KEEPSNAPS_d" -gt 0; then
    	        destroy_saved_fs "$KEEPSNAPS_d" "daily"
    	    else
    	        destroy_saved_fs "$KEEPSNAPS_h" "hourly"
    	    fi
        }
    done
    
    # check for old snapshots on local machine
    destroy_old_local () {
        p="$1";
        test "$p" = h && t=hourly;
        test "$p" = d && t=daily;
        test "$p" = w && t=weekly;
        vers="\$KEEPSNAPS_$p"
        eval vers="$vers"
        test "$RECURSIVE" = "1" && {
            FSR=""
            for i in $(zfs list -r -H -o name -t filesystem "$FS"); do
                FSR="$FSR $i"
            done
        } || FSR=$FS
        for SNAP in $FSR; do
            for oldsnap in $(zfs get -d 1 -H -r -s local -o name backup:$t "$SNAP" | $grep "$SNAP@$snappattern$" | $tail -r | eval $sed '1,"$vers"d'); do
            	test -z "$dbg" && Hint "destroying '$t' '$oldsnap' local"
                zfs destroy "$oldsnap" >/dev/null 2>&1
            done;
        done
    }
    
    Hint "destroying old snapshots off '$FS' on localhost."
    if test "$KEEPSNAPS_LOCAL" -eq 0; then
        destroy_old_local h
        destroy_old_local d
        destroy_old_local w
    else
        test "$RECURSIVE" = "1" && {
            FSR=""
            for i in $(zfs list -r -H -o name -t filesystem "$FS"); do
                FSR="$FSR $i"
            done
        } | FSR=$FS
        for SNAP in $FSR; do
            for oldsnap in $(zfs get -d 1 -H -r -s local -o name backup:hourly,backup:daily,backup:weekly "$SNAP" | $grep "$SNAP@$snappattern$" | $tail -r | eval $sed '1,"$KEEPSNAPS_LOCAL"d'); do
            	test -z "$dbg" && Hint "destroying '$oldsnap' local"
                zfs destroy "$oldsnap" >/dev/null 2>&1
            done;
        done
    fi
    
    # check for old snapshots on backup machine
    destroy_old_remote () {
        p="$1";
        test "$p" = h && t=hourly;
        test "$p" = d && t=daily;
        test "$p" = w && t=weekly;
        vers="\$KEEPSNAPS_$p"
        eval vers="$vers"
        test "$RECURSIVE" = "1" && {
            FSR=""
            for i in $(zfs list -r -H -o name -t filesystem "$FS"); do
                FSR="$FSR $i"
            done
        } || FSR=$FS
        for SNAP in $FSR; do
            for oldsnap in $($RECV_CMD zfs get -d 1 -H -r -s received -o name backup:$t "$RECVPARENTFS$SNAP" | $grep "$RECVPARENTFS$SNAP@$snappattern$" | $tail -r | eval $sed '1,"$vers"d'); do
            	test -z "$dbg" && Hint "destroying '$t' '$oldsnap' on host '$BAKSRV'."
                $RECV_CMD zfs destroy "$oldsnap" >/dev/null 2>&1
            done;
        done
    }
    
    # only execute if backups was done to $BAKSRV
    test "$TRA_TO_BAKSRV" = 1 && {
        Hint "destroying old snapshots off '$RECVPARENTFS$FS' on '$BAKSRV'."
        destroy_old_remote h
        destroy_old_remote d
        destroy_old_remote w
    }
done
# get percent used from backup zpool
test "$TRA_TO_BAKSRV" -eq 1 && {
    if test -z "$RECVPARENTFS"; then
        bzpool="${FSTOBAK%%/*}"
    else
        bzpool="${RECVPARENTFS%%/*}"
    fi
    if test "$BAKSRV" = localhost; then
        zpool list -H -o cap $bzpool > $tmpfile.bzp_used
    else
        ssh $BAKSRV "zpool list -H -o cap $bzpool" > $tmpfile.bzp_used
    fi
}
# Global Postaction
type GLOBAL_POSTACTION >/dev/null 2>&1 && {
    Hint "running GLOBAL_POSTACTION"
    eval GLOBAL_POSTACTION "$dbg" || {
        Error "Error at: running GLOBAL_POSTACTION";
    }
}
echo "$anyerr" >$tmpfile.anyerr
);
sec=$(($($date +%s) - sec))			# time needed in seconds
test -f "$tmpfile.anyerr" && {
    anyerr=$(<$tmpfile.anyerr)	# restore error code
    rm $tmpfile.anyerr # remove anyerr tempfile
}
test -f "$tmpfile.bzp_used" && {
    bzp_used=$(<$tmpfile.bzp_used)
    rm $tmpfile.bzp_used
}
test "$anyerr" = 0 && result="successfully"
test "$anyerr" = 2 && result="warning"
test "$anyerr" = 0 -o "$anyerr" = 2 || result="with error(s)"
echo "### exit ec=$result at '$($date +"%d.%m.%Y (%a), um %H:%M:%S")' (time: ${sec}s) Backup used: $bzp_used."
if test -f $tmpfile; then
    exec 1>&3 2>&1;				# restore old output
fi
} | tee -a $tmpfile
# Local Variables:
# mode:                 shell-script
# mode:                 font-lock
# comment-column:       40
# tab-width:            8
# End:
