#!/bin/bash

# do NOT run this script as root!

# ensure that the user running this script has done "s3cmd --configure" with access and secret keys,
# otherwise this script won't work



backupDir=${HOME}/libraryDBBackups
backupLogfile=/var/log/backup.last.status.log
now=`date +%a.%d_%m_%Y.%H-%M`

if [[ -e ${backupDir} ]]
then
    cd ${backupDir}
else
    mkdir ${backupDir}
    cd ${backupDir}
fi


# take the mysql DB backup
mysqldump -u root -pJGDkohaAOL13may koha_library2 | bzip2 > koha_library2.${now}.sql.bz2


# what is the most recent koha_library2 backup in this directory?
lastBackup=`ls -1 koha_library2*.bz2 | tail -1`

# upload the DB backup to S3
s3cmd put  ${lastBackup}  s3://kohalibrarydata | tee -a ${backupLogfile}


if [[ `s3cmd ls s3://kohalibrarydata | grep "${lastBackup}"` ]]
then
    echo "[DONE] [${now}] Successfully backed up koha_library2 DB and pushed it to S3" | tee -a ${backupLogfile}
    if [[ -e ${backupDir} ]]
    then
        rm -rf ${backupDir}/*
    else
        echo "[ERROR] ${backupDir} does not exist!!!" | tee -a ${backupLogfile}
    fi
else
    echo "[ERROR] [${now}] Did not find ${lastBackup} on S3... please investigate" | tee -a ${backupLogfile}
fi    


