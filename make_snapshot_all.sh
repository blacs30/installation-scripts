#!/bin/bash
# http://linuxwiki.de/rsync/SnapshotBackups

# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------
# RCS info: $Id: rsync_2fSnapshotBackups,v 1.16 2003/01/16 02:43:23 linuxwiki_de Exp $
# ----------------------------------------------------------------------
# this needs to be a lot more general, but the basic idea is it makes
# rotating backup-snapshots
# ----------------------------------------------------------------------

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/bin/echo;
MOUNT=/bin/mount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;
RSYNC=/usr/bin/rsync;
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
MOUNT_RO_STATUS=$(fgrep -c 'root/snapshot nfs ro,' /proc/mounts)

# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

if [ "$MOUNT_RO_STATUS" -eq "1" ];
        then
        echo "Mounted read only - remount rw"
        # attempt to remount the RW mount point as RW; else abort
        $MOUNT -o remount,rw $MOUNT_DEVICE $MOUNT_POINT ;
        if (( $? )); then
        {
                $ECHO "snapshot: could not remount $MOUNT_POINT readwrite";
                exit;
        }
        fi;
[[ -f $INPROGRESS_FILE ]] && rm -f $INPROGRESS_FILE
fi

echo $MYID >> $INPROGRESS_FILE
chmod 600 $INPROGRESS_FILE
echo $MYID


EXCLUDES=()
SOURCEDIRS=()
DESTDIR=()

for i in "$@"
do
  echo $i
case $i in
    -e=*|--excludes=*)
  #  EXCLUDES="${i#*=}"
    EXCLUDES+=("${i#*=}")
    shift # past argument=value
    ;;
    -s=*|--sourcedir=*)
  #  SOURCEDIRS="${i#*=}"
    SOURCEDIRS+=("${i#*=}")
    shift # past argument=value
    ;;
    -d=*|--destdir=*)
  #  DESTDIR="${i#*=}"
    DESTDIR+=("${i#*=}")
    shift # past argument=value
    ;;
    *)
            # unknown option
    ;;
esac
done
echo "EXCLUDE PATHS  = ${EXCLUDES[@]}"
echo "SOURCE DIRECTORY     = ${SOURCEDIRS[@]}"
echo "DESTINATION DIRECTORY    = ${DESTDIR[@]}"
if [[ -n $1 ]]; then
    echo "Last line of file specified as non-opt/last argument:"
    tail -1 $1
fi



for i in "${EXCLUDES[@]}"
do
RSYNC_EXCLUDE="$RSYNC_EXCLUDE --exclude $i"
done
echo $RSYNC_EXCLUDE





# step 1: delete the oldest snapshot, if it exists:
if [ -d $DEST_FOLDER/hourly.3 ] ; then                     \
$RM -rf $DEST_FOLDER/hourly.3 ;                            \
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
if [ -d $DEST_FOLDER/hourly.2 ] ; then                     \
$MV $DEST_FOLDER/hourly.2 $DEST_FOLDER/hourly.3 ;     \
fi;
if [ -d $DEST_FOLDER/hourly.1 ] ; then                     \
$MV $DEST_FOLDER/hourly.1 $DEST_FOLDER/hourly.2 ;     \
fi;

# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
if [ -d $DEST_FOLDER/hourly.0 ] ; then                     \
$CP -al $DEST_FOLDER/hourly.0 $DEST_FOLDER/hourly.1 ; \
fi;

# step 4: rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
$RSYNC                                                          \
        -va --delete --delete-excluded                          \
        --exclude="$EXCLUDE1" --exclude="$EXCLUDE2"             \
        $SRC_FOLDER $DEST_FOLDER/hourly.0 ;

# step 5: update the mtime of hourly.0 to reflect the snapshot time
$TOUCH $DEST_FOLDER/hourly.0 ;

# remove entry in progress file
sed -i "/.*$MYID.*/d" $INPROGRESS_FILE

# count lines in file
ACTIVE_SYNCS=$(wc -l $INPROGRESS_FILE | awk '{print $1}')
# count active processes in scripts dirctory
ACTIVE_PROCESSES=$(ps aux | grep -c '\/var\/scripts\/[a-zA-Z0-9]*.sh')


if [[ $ACTIVE_SYNCS -ge 1 ]] || [[ $ACTIVE_PROCESSES -ge 1 ]]
        then
        echo "Other syncs are still running - don't remount ro"
else
  # delete inprogress file now
  rm -f $INPROGRESS_FILE
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
