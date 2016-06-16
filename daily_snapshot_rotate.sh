# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility: daily snapshots
# ----------------------------------------------------------------------
# RCS info: $Id: rsync_2fSnapshotBackups,v 1.16 2003/01/16 02:43:23 linuxwiki_de Exp $
# ----------------------------------------------------------------------
# intended to be run daily as a cron job when hourly.3 contains the
# midnight (or whenever you want) snapshot; say, 13:00 for 4-hour snapshots.
# ----------------------------------------------------------------------

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/bin/echo;

MOUNT=/bin/mount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
MYID="$$"

# ------------- file locations -----------------------------------------

MOUNT_DEVICE=NFS_SERVER_IP:/NFS_SHARE;
MOUNT_POINT=/root/backup;
# EXCLUDES=/var/scripts/excludes.txt; for files
EXCLUDE1=$3;
EXCLUDE2=$4;
SRC_FOLDER=$1;
DEST_FOLDER=$2;
INPROGRESS_FILE="$MOUNT_POINT/backup.inprogress";

# ------------- the script itself --------------------------------------

# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

# attempt to remount the RW mount point as RW; else abort
$MOUNT -o remount,rw $MOUNT_DEVICE $SNAPSHOT_RW ;
if (( $? )); then
{
        $ECHO "snapshot: could not remount $SNAPSHOT_RW readwrite";
        exit;
}
fi;


# step 1: delete the oldest snapshot, if it exists:
if [ -d $SNAPSHOT_RW/home/daily.2 ] ; then                      \
$RM -rf $SNAPSHOT_RW/home/daily.2 ;                             \
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
if [ -d $SNAPSHOT_RW/home/daily.1 ] ; then                      \
$MV $SNAPSHOT_RW/home/daily.1 $SNAPSHOT_RW/home/daily.2 ;       \
fi;
if [ -d $SNAPSHOT_RW/home/daily.0 ] ; then                      \
$MV $SNAPSHOT_RW/home/daily.0 $SNAPSHOT_RW/home/daily.1;        \
fi;

# step 3: make a hard-link-only (except for dirs) copy of
# hourly.3, assuming that exists, into daily.0
if [ -d $SNAPSHOT_RW/home/hourly.3 ] ; then                     \
$CP -al $SNAPSHOT_RW/home/hourly.3 $SNAPSHOT_RW/home/daily.0 ;  \
fi;

# note: do *not* update the mtime of daily.0; it will reflect
# when hourly.3 was made, which should be correct.

# now remount the RW snapshot mountpoint as readonly


# remove entry in progress file
sed -i "/.*$MYID.*/d" $INPROGRESS_FILE

# count lines in file
ACTIVE_SYNCS=$(wc -l $INPROGRESS_FILE | awk '{print $1}')

[[ $ACTIVE_SYNCS -eq 0 ]] && rm -f $INPROGRESS_FILE

if [[ $ACTIVE_SYNCS -ge 1 ]]
        then
        echo "Other syncs are still running - don't remount ro"
else
  # now remount the RW snapshot mountpoint as readonly
  $MOUNT -o remount,ro $MOUNT_DEVICE $MOUNT_POINT ;
  if (( $? ))
	then
  	{
          $ECHO "snapshot: could not remount, $MOUNT_POINT is in use"
          exit
  	}
	fi
fi
