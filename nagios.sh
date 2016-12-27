#!/bin/bash 
#
DESCRIPTION="Parser for censhare Nagios requests over ssh"
COPYRIGHT="(C) 2008-2010 censhare AG"
# Authors: ms@coware.de, Patricia Jung <pju@censhare.de>

# History:
REVISION=" 02-01-2011 <mh@censhare.de>: add default options for check_rman_memory"
#	   12-09-2010 <mh@censhare.de>: add check_rman_memory"
#	   11-26-2010 <mh@censhare.de>: add check_zpool_state" 
#	   11-23-2010 <pju@censhare.de>: JMX_RENDERER_OPT might be customised"
#	   07-22-2010 <mh@censhare.de>: added check_log_backup"
#	   05-14-2010 <pj@censhare.de>: disable usage of /opt/csw/lib/ in LD_LIBRARY_PATH by means of new variable OPENCSW to be defined in censhare-nagios.conf
#          01-12-2010 <pj@censhare.de>: jmx_renderer: check for JAVA_HOME and try to load .profile if undefined
#                                       Include  /opt/csw/lib/ in LD_LIBRARY_PATH only if existant
#          11-25-2009 <pj@censhare.de>: - not allowed in bash variable names => substitute _ for - in *_OPT variable names
#          10-13-2009 <pj@censhare.de>: Don't include /opt/csw/lib/ in LD_LIBRARY_PATH on SunOS Generic_141415-10 (breaks s2s check, see ticket  #777280)
#          09-09-2009 <pj@censhare.de>: Allow config file specification for check_censhare
#          07-30-2009 <pj@censhare.de>: Use GREP defined in censhare.common.nagios, define TR to make sure we can use GNU tr
#          07-13-2009 <pj@censhare.de>: Added s2s check
#          07-02-2009 <pj@censhare.de>: Added css-sync check
#          06-23-2009 <pj@censhare.de>: Added Java heapspace check
#          05-25-2009 <pj@censhare.de>: Adapted check_load parameters to more sensible ones
#          05-12-2009 <pj@censhare.de>: css_users is no longer a separate chek (included in censhare)
#          04-27-2009 <pj@censhare.de>: We no longer differentiate between CANON_ROOT and CANON_CORPUS as it ist Nagios' task to define whether a plugin is run as corpus or root
#          04-21-2009 <pj@censhare.de>: Censhare test is part of CANON_ROOT as it is checked directly by corpus (no su necessary)
#          04-21-2009 <pj@censhare.de>: Some of the plugins from CANON_ROOT are third party and therefore located in a different path
#          04-15-2009 <pj@censhare.de>: Changed severe pattern to SEVERE as check_log_severe checks only the 2nd colum of the log file for this pattern
#          04-09-2009 <pj@censhare.de>: Run oratns as user oracle
#          04-07-2009 <pj@censhare.de>: Set LD_LIBRARY_PATH on Solaris
#          04-03-2009 <pj@censhare.de>: Always return RET_CODE
#          04-02-2009 <pj@censhare.de>: CSS_USERS_OPT: ignore java exceptions
#          04-01-2009 <pj@censhare.de>: unified the plugin run code
#                                       name the supported plugins in usage 
#                                       css_users will be checked by corpus
#                                       argument all "runs" all defined tests
#          03-23-2009 <pj@censhare.de>: 'SEVERE :' as default search pattern for severe check
#          03-13-2009 <pj@censhare.de>: usage adapted to the plugins, allows now for site-specific configuration in $NAGPATH/etc/censhare-nagios.conf
# pju 12-Mar-2009 check_jmx_renderer to check number of InDesign-renderers
# pju 09-Mar-2009 check_log_severe based on home-grown plugin
# pju 20-Jan-2009 check_log_gc checks FullGC runtimes in ~$CORPUS/work/logs/gc.log
# pju 16-Jan-2009 check_log checks for SEVERE messages in ~$CORPUS/work/logs/server-0.0.log
#                 read the CORPUS user from the censhare configuration if possible
# ms  25-Jul-2008 initial	

# Usage: /path/to/nagios.sh <plugin_name>|all [reset]

# PATH to Censhare Nagios stuff
NAGPATH="/usr/local/nagios"

WORKDIR=$(dirname $0)
# source functions and variables common to all plugins
COMMON=$WORKDIR/censhare.common.nagios
if test ! -f  $COMMON; then
    echo "$0: Can't find $COMMON"
    exit 3
else
    . $COMMON
fi

for TR in "/usr/local/bin/tr" "/usr/bin/tr" "not/found"; do
    if test -x $TR; then break; fi
done
if test $TR = "not/found"; then unknown_prog "tr"; fi


# Read the CORPUS user from the configuration file if possible
if test -f /etc/s2s/sysconfig/censhare; then
	. /etc/s2s/sysconfig/censhare
elif test -f /etc/sysconfig/censhare; then
	. /etc/sysconfig/censhare
fi
 
if test -z $CORPUS; then
	CORPUS=corpus #set default corpus user
fi

# Default settings which may be overwritten by local configuration

CENSHARE_OPT=""
CPU_OPT=" -w 10 -c 5"
DISK_OPT=" -w 10% -c 5% -p /"
LOAD_OPT="-r -w 13.0,8.0,3.0 -c 15.0,10.0,5.0"
MEM_OPT=" -w 10 -c 5"
ORACLE_OPT=" --db $CORPUS"
ORATNS_OPT=" --tns $CORPUS"
PROCS_OPT=" -w 250 -c 400 -s RSZDT"
SWAP_OPT=" -a -w 20% -c 10%"
RMAN_MEMORY_OPT=" -w 30 -c 20"
LOG_GC_OPT=' -F work/logs/gc.log -O work/logs/gc.log.old_for_nagios -c 20 -w 10'
LOG_SEVERE_OPT=' -F work/logs/server-0.0.log -O work/logs/server-0.0.log.old_for_nagios -q "SEVERE"'
LOG_SEVERE_RESET_FILE='work/logs/server-0.0.log.old_for_nagios.STATE'
LOG_HEAPSPACE_OPT=" -F apache0/logs/catalina.$(date +%Y-%m-%d).log -O apache0/logs/catalina.log.old_for_nagios"
LOG_BACKUP_OPT=" -F /var/log/zpoolbackup.log -b ZPOOL"

# May be overwritten by local configuration

if test -f $NAGPATH/etc/censhare-nagios.conf; then
    . $NAGPATH/etc/censhare-nagios.conf
fi

# if usage of OPENCSW is not disabled in censhare-nagios.conf
if test -z $OPENCSW || test $OPENCSW == "yes" ; then
    if test -d /opt/csw/lib/ && test $(uname -v) != "Generic_141415-10"; then 
        #pju: see ticket #777280 
        export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/csw/lib/
    fi
else
    LD_LIBRARY_PATH=$(echo $LD_LIBRARY_PATH | $SED -e "s/\\/opt\\/csw\\/lib//g" -e "s/::/:/g")
fi

# The following commands don't use options, therefore they must not be 
#overwritten
S2S_OPT=""

# For enhanced security we define a prefix path for the plugins to call
COMMAND_PREFIX="$NAGPATH/bin/plugins/check_"
COMMAND=$COMMAND_PREFIX


# Things we check
CANON="censhare jmx_renderer log_backup log_css-sync zpool_state log_gc log_severe log_heapspace cpu disk load mem oracle oratns procs s2s swap rman_memory" 
# of which the following are third party plugins 
THIRD_PARTY="disk load oracle oratns procs swap"


usage() {
    $ECHO "Usage: $RUNAS <plugin> [reset]\n\n<plugin> may be one of the following:\n\t$CANON\n\n"
    $ECHO "       $RUNAS all\n"
    $ECHO "       $RUNAS --help|-h\n"
    $ECHO "       $RUNAS --version|-V\n"
}

RESET="no"
# Check that the script was invoked with 1 or 2 arguments
case "$#" in
    1) OPT=$(echo $1 | $TR '[:upper:]' '[:lower:]');;
    2) if test "$2" = "reset"; then 
           OPT=$(echo $1 | $TR '[:upper:]' '[:lower:]')
           RESET="yes"
       else usage 
       fi ;;
    *) usage
       exit $STATE_UNKNOWN;;
esac

# set path for non-Censhare plugins
command_path () {
   echo $THIRD_PARTY | $GREP -w $1 > /dev/null
   if test $? -eq 0; then 
       COMMAND="$NAGPATH/bin/plugins/third_party/check_"
   else
       COMMAND=$COMMAND_PREFIX
   fi
}

run () {
   flags=$(echo $1  |$TR '[:lower:]' '[:upper:]' | $TR '-' '_')_OPT
   OUTPUT=`${COMMAND}$1 ${!flags}`
   RET_CODE=$?
}

case $OPT in
        -h | --help)            
            help
            exit $STATE_OK
            ;;
        -v | --version)
            version
            exit $STATE_OK
            ;;
        all) for nagtest in $CANON; do 
                 $ECHO "\n$nagtest: "
                 command_path $nagtest
                 if test "$nagtest" != "oratns"; then
                     run $nagtest
                 else # oratns
                     OUTPUT=`su - oracle -c "test -f ~/.profile && .  ~/.profile; ${COMMAND}oracle $ORATNS_OPT"` 
                 fi
                 echo "$OUTPUT"
             done
             exit $RET_CODE
             ;;
        oratns) command_path $OPT
                OUTPUT=`su - oracle -c "${COMMAND}oracle $ORATNS_OPT"` 
                RET_CODE=$?;;
	log_severe) 
        if test "$RESET" = "yes"; then
            OUTPUT=`printf '0\n' > $LOG_SEVERE_RESET_FILE`
            RET_CODE=$? 
        else
            OUTPUT=`${COMMAND}log_severe $LOG_SEVERE_OPT`; RET_CODE=$?
        fi ;;
        # Solaris-grep kennt kein -q, daher der Umweg ueber /dev/null
        # dito die Abfrage von $? in einem separaten test als
        # Zugestaendnis an die Kompatibilitaet
        *) echo $CANON | $GREP -w $OPT > /dev/null
           if test $? -eq 0; then
               if test $OPT == "jmx_renderer"; then
               # try to set the JAVA_HOME variable if not set
                   test -z $JAVA_HOME && test -s ~/.profile && . ~/.profile 
               fi
               command_path $OPT
               run $OPT
           else
	       echo "Unknown plugin $COMMAND$OPT"
               usage
               exit $STATE_UNKNOWN
           fi ;;
esac

echo "$OUTPUT" # use echo instead of printf as printf interprets a lot
               # of characters used in plugin output as special ones
exit $RET_CODE
