#!/bin/bash

# do NOT run this script as root!

# ensure that the user running this script has done "s3cmd --configure" with access and secret keys,
# otherwise this script won't work



backupDir=${HOME}/libraryDBBackups
backupLogfile=/var/log/backup.last.status.log
s3Bucket="s3://kohalibrarydata"
s3CMD=/usr/local/bin/s3cmd
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
lastBackup=`ls -1rt koha_library2*.bz2 | tail -1`
#echo "[DEBUG] lastBackup is: ${lastBackup}" | tee -a ${backupLogfile} 
#echo "[DEBUG] s3Bucket is: ${s3Bucket}" | tee -a ${backupLogfile} 


# upload the DB backup to S3
${s3CMD} put  ${lastBackup} ${s3Bucket}  | tee -a ${backupLogfile}


if [[ `${s3CMD} ls ${s3Bucket} | grep "${lastBackup}"` ]]
then
    echo -e "[DONE] [${now}] Successfully backed up koha_library2 DB and pushed it to S3\n\n" | tee -a ${backupLogfile}
    if [[ -e ${backupDir} ]]; then
        rm -rf ${backupDir}/*.bz2
    else
        echo "[ERROR] ${backupDir} does not exist!!!" | tee -a ${backupLogfile}
    fi
else
    echo -e "[ERROR] [${now}] Did not find ${lastBackup} on S3... please investigate\n\n" | tee -a ${backupLogfile}
fi    


