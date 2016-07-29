#!/bin/bash
# Script fuer inkrementelles Backup mit 30 taegigem Vollbackup
LOG_FILE=/tmp/incremental_backuplog.txt
exec &> $LOG_FILE

### Einstellungen ##
BACKUPDIR="media/backup"           ## Pfad zum Backupverzeichnis
CONFIG_DB_BACKUPDIR="media/confdbbackup"
TMP_MYSQLDB_BACKUP_DIR="tmp/mysqlbackup"
ROTATEDIR="media/backup/rotate"    ## Pfad wo die Backups nach 30 Tagen konserviert werden
ROTATEDIR_CONFIGDB="media/confdbbackup/rotate"    ## Pfad wo die Backups nach 30 Tagen konserviert werden
TIMESTAMP="timestamp.dat"          ## Zeitstempel
SOURCE="home/user"                 ## Verzeichnis(se) welche(s) gesichert werden soll(en)
SOURCE_CONF_DB="$TMP_MYSQLDB_BACKUP_DIR home/user"                 ## Verzeichnis(se) welche(s) gesichert werden soll(en)
DATUM="$(date +%d-%m-%Y)"          ## Datumsformat einstellen
ZEIT="$(date +%H:%M)"              ## Zeitformat einstellen
MOUNT_DEVICE=NFS_SERVER_IP:/NFS_SHARE;
MOUNT_POINT=/root/snapshot;
INPROGRESS_FILE="$MOUNT_POINT/backup.inprogress";
ID=/usr/bin/id;
MYID="$$"
GZIPCHECK=();
### MYSQL Setup ###
MUSER="mysqlbackup";
MPASS="mysqlpass";
MHOST="localhost";
MPORT="3306";
IGNOREDB="
information_schema
mysql
test
"

### Verzeichnisse/Dateien welche nicht gesichert werden sollen ! Achtung keinen Zeilenumbruch ! ##
EXCLUDE="--exclude=home/user/Filme --exclude=home/user/Musik --exclude=home/user/Spiele --exclude=home/user/.VirtualBox  --exclude=home/user/.local/share/Trash"
EXCLUDE_CONF_DB="--exclude=home/user/Filme --exclude=home/user/Musik --exclude=home/user/Spiele --exclude=home/user/.VirtualBox  --exclude=home/user/.local/share/Trash"

# make sure we're running as root
if (( `$ID -u` != 0 )); then { echo "Sorry, must be root.  Exiting..."; exit; } fi
MOUNT_RO_STATUS=$(fgrep -c 'root/snapshot nfs ro,' /proc/mounts)
if [ "$MOUNT_RO_STATUS" -eq "1" ];
        then
        echo "Mounted read only - remount rw"
        # attempt to remount the RW mount point as RW; else abort
        mount -o remount,rw $MOUNT_DEVICE $MOUNT_POINT ;
        if (( $? )); then
        {
                echo "snapshot: could not remount $MOUNT_POINT readwrite";
                exit;
        }
        fi;
[[ -f $INPROGRESS_FILE ]] && rm -f $INPROGRESS_FILE
fi
echo $MYID >> $INPROGRESS_FILE
chmod 600 $INPROGRESS_FILE

backup_mysql_dbs() {

  ### Create backup dir ###
  if [ ! -d $TMP_MYSQLDB_BACKUP_DIR ]; then
    mkdir -p $TMP_MYSQLDB_BACKUP_DIR
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
          FILE="TMP_MYSQLDB_BACKUP_DIR/$NOWFILE-$db.sql.gz";
          echo "BACKING UP $db";
          mysqldump --add-drop-database --opt --lock-all-tables -u $MUSER -p$MPASS -h $MHOST -P $MPORT $db | gzip > $FILE
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

  # step 5: update the mtime of hourly.0 to reflect the snapshot time
  $TOUCH $TMP_MYSQLDB_BACKUP_DIR ;

  ### If all files check out, delete the oldest dir ###
  if [ "$CHECKSUM" == "$CHECKOUTS" ]; then
      echo "All files checked out ok. MYSQLDUMP successful.";
      mail -s "MYSQLDUMP Success Backuplog" mail@example.com < $LOG_FILE;
  else
      echo "Dispatching Karl, he's an Expert";
      ### Send mail with contents of logfile ###
      mail -s "MYSQLDUMP ERROR Backuplog" mail@example.com < $LOG_FILE;
  fi
}

# run function for mysql database backup
backup_mysql_dbs

### Wechsel in root damit die Pfade stimmen ##
cd /

### Backupverzeichnis anlegen ##
mkdir -p ${BACKUPDIR}
mkdir -p ${CONFIG_DB_BACKUPDIR}

### Test ob Backupverzeichnis existiert und Mail an Admin bei fehlschlagen ##
if [ ! -d "${BACKUPDIR}" ] || [ ! -d "${CONFIG_DB_BACKUPDIR}" ] ; then

mail -s "Backupverzeichnis nicht vorhanden!" mail@example.com <<EOM
Hallo Admin,
das Backup am ${DATUM} konnte nicht erstellt werden. Das Verzeichnis ${BACKUPDIR} oder ${CONFIG_DB_BACKUPDIR} wurde nicht gefunden und konnte auch nicht angelegt werden.
Mit freundlichem Gruss Backupscript
EOM

 . exit 1
fi

### Alle Variablen einlesen und letzte Backupdateinummer herausfinden ##
set -- ${BACKUPDIR}/backup-???.tgz
lastname=${!#}
backupnr=${lastname##*backup-}
backupnr=${backupnr%%.*}
backupnr=${backupnr//\?/0}
backupnr=$[10#${backupnr}]

### Backupdateinummer automatisch um +1 bis maximal 30 erhoehen ##
if [ "$[backupnr++]" -ge 30 ]; then
mkdir -p ${ROTATEDIR}/${DATUM}-${ZEIT}
mkdir -p ${ROTATEDIR_CONFIGDB}/${DATUM}-${ZEIT}

### Test ob Rotateverzeichnis existiert und Mail an Admin bei fehlschlagen ##
if [ ! -d "${ROTATEDIR}/${DATUM}-${ZEIT}" ] || [ ! -d "${ROTATEDIR_CONFIGDB}/${DATUM}-${ZEIT}" ]; then

mail -s "Rotateverzeichnis nicht vorhanden!" mail@example.com <<EOM
Hallo Admin,
die alten Backups konnten am ${DATUM} nicht verschoben werden. Das Verzeichnis ${ROTATEDIR} oder ${ROTATEDIR_CONFIGDB} wurde nicht gefunden und konnte auch nicht angelegt werden.
Mit freundlichem Gruss Backupscript
EOM

 . exit 1
else
mv ${BACKUPDIR}/* ${ROTATEDIR}/${DATUM}-${ZEIT}
mv ${CONFIG_DB_BACKUPDIR}/* ${ROTATEDIR_CONFIGDB}/${DATUM}-${ZEIT}
fi

### Abfragen ob das Backupverschieben erfolgreich war ##
if [ $? -ne 0 ]; then

mail -s "Backupverschieben fehlerhaft!" mail@example.com <<EOM
Hallo Admin,
die alten Backups konnte am ${DATUM} nicht verschoben werden.
Mit freundlichem Gruss Backupscript
EOM

exit 1
else

mail -s "Backupverschieben erfolgreich" mail@example.com <<EOM
Hallo Admin,
die alten Backups wurde am ${DATUM} erfolgreich nach ${ROTATEDIR}/${DATUM}-${ZEIT} verschoben.
Mit freundlichem Gruss Backupscript
EOM

### die Backupnummer wieder auf 1 stellen ##
backupnr=1
fi
fi

backupnr=000${backupnr}
backupnr=${backupnr: -3}
filename=backup-${backupnr}.tgz

### Nun wird das eigentliche Backup ausgefuehrt ##
SOURCE_SUCCESS=Successful
tar -cpzf ${BACKUPDIR}/${filename} -g ${BACKUPDIR}/${TIMESTAMP} ${SOURCE} ${EXCLUDE}

### Abfragen ob das Backup erfolgreich war ##
if [ $? -ne 0 ]; then
SOURCE_SUCCESS=fehler
mail -s "Backup (${SOURCE}) war fehlerhaft!" mail@example.com <<EOM
Hallo Admin,
das Backup ${filename} am ${DATUM} wurde mit Fehler(n) beendet.
Mit freundlichem Gruss Backupscript
EOM
fi

SOURCE_CONF_DB_SUCCESS=Successful
tar -cpzf ${CONFIG_DB_BACKUPDIR}/${filename} -g ${CONFIG_DB_BACKUPDIR}/${TIMESTAMP} ${SOURCE_CONF_DB} ${EXCLUDE_CONF_DB}

### Abfragen ob das Backup erfolgreich war ##
if [ $? -ne 0 ]; then
SOURCE_CONF_DB_SUCCESS=fehler
mail -s "Backup (${SOURCE_CONF_DB}) war fehlerhaft!" mail@example.com <<EOM
Hallo Admin,
das Backup ${filename} am ${DATUM} wurde mit Fehler(n) beendet.
Mit freundlichem Gruss Backupscript
EOM
fi


mail -s "Backup (${SOURCE}) war $SOURCE_SUCCESS und von (${SOURCE_CONF_DB}) war $SOURCE_CONF_DB_SUCCESS" mail@example.com <<EOM
Hallo Admin,
das Backup von $SOURCE mit Namen ${filename} am ${DATUM} wurde erfolgreich in ${BACKUPDIR}/${TIMESTAMP} gebackupt.
das Backup von $SOURCE_CONF_DB mit Namen ${filename} am ${DATUM} wurde erfolgreich in ${CONFIG_DB_BACKUPDIR}/${TIMESTAMP} gebackupt.
Mit freundlichem Gruss Backupscript
EOM

fi

# remove temporary mysql exports
rm -rf $TMP_MYSQLDB_BACKUP_DIR
# remove entry in progress file
sed -i "/.*$MYID.*/d" $INPROGRESS_FILE
# count lines in file
ACTIVE_SYNCS=$(wc -l $INPROGRESS_FILE | awk '{print $1}')
if [[ $ACTIVE_SYNCS -ge 1 ]]
        then
        echo "Other syncs are still running - don't remount ro"
        mail -s "Other syncs are still running - don't remount ro" mail@example.com
else
  # delete inprogress file now
  rm -f $INPROGRESS_FILE
  # now remount the RW snapshot mountpoint as readonly
  mount -o remount,ro $MOUNT_DEVICE $MOUNT_POINT ;
  if (( $? ))
	then
  	{
          echo "snapshot: could not remount, $MOUNT_POINT is in use"
          mail -s "snapshot: could not remount, $MOUNT_POINT is in use" mail@example.com
          exit
  	}
	fi
fi
