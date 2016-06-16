#!/bin/bash
### Write log to temporary file  ###
### from https://github.com/webstylr/simple-mysqlbackup/blob/master/mysqlbackup.sh
exec &> /tmp/backuplog.txt

# ------------- system commands used by this script --------------------
ID=/usr/bin/id;
ECHO=/bin/echo;

MOUNT=/bin/mount;

MOUNT_DEVICE=NFS_SERVER_IP:/NFS_SHARE;
MOUNT_POINT=/root/backup;
INPROGRESS_FILE="$MOUNT_POINT/backup.inprogress";
MYID="$$"

### Defaults Setup ###
STORAGEDIR="/root/snapshot/backup/db";
NOW=`date "+%s"`;
OLDESTDIR=`ls $STORAGEDIR | head -1`;
NOWDIR=`date +"%Y-%m-%d"`;
NOWFILE=`date +"%Y-%m-%d"`;
OLDEST=`date -d "$OLDESTDIR" "+%s"`;
BACKUPDIR="$STORAGEDIR/$NOWDIR";
DIFF=$(($NOW-$OLDEST));
DAYS=$(($DIFF/ (60*60*24)));
DIRLIST=`ls -lRh $BACKUPDIR`;
ROTATION="14"
GZIPCHECK=();
### Server Setup ###
MUSER="mysqlbackup";
MPASS="Cla_Lis88";
MHOST="localhost";
MPORT="3306";
IGNOREDB="
information_schema
mysql
test
"
MYSQL=`which mysql`;
MYSQLDUMP=`which mysqldump`;
GZIP=`which gzip`;

# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

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

### Create backup dir ###
if [ ! -d $BACKUPDIR ]; then
  mkdir -p $BACKUPDIR
    if [ "$?" = "0" ]; then
        :
    else
        echo "Couldn't create folder. Check folder permissions and/or disk quota!"
    fi
else
 :
fi

### Get the list of available databases ###
DBS="$(mysql -u $MUSER -p$MPASS -h $MHOST -P $MPORT -Bse 'show databases')"

### Backup DBs ###
for db in $DBS
do
    DUMP="yes";
    if [ "$IGNOREDB" != "" ]; then
        for i in $IGNOREDB
        do
            if [ "$db" == "$i" ]; then
                    DUMP="NO";
            fi
        done
    fi

    if [ "$DUMP" == "yes" ]; then
        FILE="$BACKUPDIR/$NOWFILE-$db.sql.gz";
        echo "BACKING UP $db";
        $MYSQLDUMP --add-drop-database --opt --lock-all-tables -u $MUSER -p$MPASS -h $MHOST -P $MPORT $db | gzip > $FILE
        if [ "$?" = "0" ]; then
            gunzip -t $FILE;
            if [ "$?" = "0" ]; then
                GZIPCHECK+=(1);
                echo `ls -alh $FILE`;
            else
                GZIPCHECK+=(0);
                echo "Exit, gzip test failed.";
            fi
        else
            echo "Dump of $db failed!"
        fi
    fi
done;

### Check if gzip test for all files was ok ###
CHECKOUTS=${#GZIPCHECK[@]};
for (( i=0;i<$CHECKOUTS;i++)); do
    CHECKSUM=$(( $CHECKSUM + ${GZIPCHECK[${i}]} ));
done

### If all files check out, delete the oldest dir ###
if [ "$CHECKSUM" == "$CHECKOUTS" ]; then
    echo "All files checked out ok. Deleting oldest dir.";
    ## Check if Rotation is true ###
    if [ "$DAYS" -ge $ROTATION ]; then
        rm -rf $STORAGEDIR/$OLDESTDIR;
        if [ "$?" = "0" ]; then
            echo "$OLDESTDIR deleted."
        else
            ### Error message with listing of all dirs ###
            echo "Couldn't delete oldest dir.";
            echo "Contents of current Backup:";
            echo " ";
            echo $DIRLIST;
        fi
    else
        :
    fi
else
    echo "Dispatching Karl, he's an Expert";
    ### Send mail with contents of logfile ###
    mail -s "Backuplog" mail@lisowski-development.de < /tmp/backuplog.txt;
fi

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
