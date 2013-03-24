#!/bin/bash


backupDir=/home/ambar/libraryDBBackups
backupLogfile=${HOME}/backup.last.status.log
now=`date +%a.%d_%m_%Y.%H-%M`

cd $backupDir


# take the mysql DB backup
mysqldump -u root -pJGDkohaAOL13may koha_library2 | bzip2 > koha_library2.${now}.sql.bz2


# what is the most recent koha_library2 backup in this directory?
lastBackup=`ls -1 koha_library2*.bz2 | tail -1`

# upload the DB backup to S3
s3cmd put  ${lastBackup}  s3://kohalibrarydata


if [[ `s3cmd ls s3://kohalibrarydata | grep "${lastBackup}"` ]]
then
    echo "[DONE] [${now}] Successfully backed up koha_library2 DB and pushed it to S3" | tee -a ${backupLogfile}
    rm -rf $backupDir/*
else
    echo "[ERROR] [${now}] Did not find ${lastBackup} on S3... please investigate" | tee -a ${backup}
fi    


