#*******************************************************************************
# Script: dbrefresh.sh
# Author: Somu Rajarathinam (somu)
# Date  : 2019-08-07
#
# Purpose: Script for creating/refreshing a clone of an Oracle DB (Dev/QA/Stg)
#          using Pure FlashArray snapshot of the Oracle Standby database
#
#*******************************************************************************
# Prerequisites/Assumptions:
# 1. The protection group consists of two volumes, data and fra
# 2. The target volumes are mounted under /db/<dev|qa|stg>/<mount> directory
#    <mount> directory should be the same as the source standby volume mount points
#    In this example the source standby volumes are mounted under /p02 and /p03
#    Hence the target volumes for DEV would be /db/dev/p02 and /db/dev/p03
# 3. The target volumes should have been discovered and mounted to target server
# 4. Target server to have the same Oracle binaries installed as that of source
# 5. Copy the init.ora file from source and make changes so it reflect target
# 6. Standby database includes 3 standby redo logs
#
#
#*******Disclaimer:*************************************************************
# This script is offered "as is" with no warranty.  While this script is
# tested and worked in my environment, it is recommended that you test
# this script in a test lab before using in a production environment.
# tested and worked in my environment, it is recommended that you test
# this script in a test lab before using in a production environment.
# No written permission needed to use this script but me or Pure Storage
# will not be liable for any damage or loss to the system.
#*******************************************************************************
#
# Usage: dbrefresh.sh [dev|qa|stg] <pg> <snap suffix>
#
#
# PG consists of two volumes, data and fra

export SDIR=/home/oracle/demo
cd $SDIR

if [ $# -ne 3 ]; then
  echo "Usage: ${0} [dev|qa|stg] <pg> <snap suffix>"
  exit -1
fi

export ORACLE_SID=$1
ct=$(ps -ef|grep smon|grep $1|grep -v grep)
if [ "${#ct}" -gt 0 ]; then
   sqlplus -s / as sysdba << EOF
   shutdown abort;
   exit
EOF
fi

db=${1^^}  # Convert to upper case

case $db in

  DEV)  echo "Cloning DEV instance"
        if grep -qs "/db/dev/p0[23]" /proc/mounts; then
           sudo umount /db/$1/p02
           sudo umount /db/$1/p03
        fi
        $SDIR/pureclone.py --array 10.0.2.87 --srcPG $2 --tgtVols fs_target_devdata,fs_target_devfra --suffix $3
        ;;
   QA)  echo "Cloning QA instance"
        if grep -qs "/db/qa/p0[23]" /proc/mounts; then
           sudo umount /db/$1/p02
           sudo umount /db/$1/p03
        fi
        $SDIR/pureclone.py --array 10.0.2.87 --srcPG $2 --tgtVols fs_target_qadata,fs_target_qafra --suffix $3
        ;;
  STG)  echo "Cloning STG instance"
        if grep -qs "/db/stg/p0[23]" /proc/mounts; then
           sudo umount /db/$1/p02
           sudo umount /db/$1/p03
        fi
        $SDIR/pureclone.py --array 10.0.2.87 --srcPG $2 --tgtVols fs_target_stgdata,fs_target_stgfra --suffix $3
        ;;
    *)  echo "Incorrect instance type"
        exit -1
esac

# Mount the filesystems

sudo mount /db/$1/p02
sudo mount /db/$1/p03

# Rename the directories
mv /db/$1/p02/oradata/prod_sby /db/$1/p02/oradata/$1
mv /db/$1/p03/fra/prod_sby /db/$1/p03/fra/$1
mv /db/$1/p03/fra/PROD_SBY /db/$1/p03/fra/${1^^}

# Setup symbolic link to Standby database
rm -f /p02/oradata/prod_sby/sby*.log
ln -s /db/$1/p02/oradata/$1/sby_redo01.log /p02/oradata/prod_sby/sby_redo01.log
ln -s /db/$1/p02/oradata/$1/sby_redo02.log /p02/oradata/prod_sby/sby_redo02.log
ln -s /db/$1/p02/oradata/$1/sby_redo03.log /p02/oradata/prod_sby/sby_redo03.log

# Startup the database in mount mode

echo "Setting up the $1 database"
echo " "
export ORACLE_SID=$1
sqlplus -s / as sysdba <<EOF2
startup mount pfile='/home/oracle/demo/init$1.ora'
@alterdb.sql $1
@rename_files.gsql
@drop_sby.gsql
alter database activate standby database;
shutdown immediate;
EOF2

echo "Starting up the $1 database"
sqlplus -s / as sysdba <<EOF3
startup pfile='/home/oracle/demo/init$1.ora'
EOF3
