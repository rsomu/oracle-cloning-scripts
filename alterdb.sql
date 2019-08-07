/*******************************************************************************
# Script: alterdb.sql
# Author: Somu Rajarathinam (somu)
# Date  : 2019-08-07
#
# Purpose: SQL for creating script to rename the datafiles and drop standby log files
# Usage: @alterdb.sql <db name>
#
#*******************************************************************************
# Prerequisites/Assumptions:
# 1. This script is expected to be run under the Standby database
# 2. The standby database name is prod_sby
# 3. The target volumes are mounted under /db/<dev|qa|stg>/<mount> directory
#    <mount> directory should be the same as the source standby volume mount points
#    In this example the source standby volumes are mounted under /p02 and /p03
#    Hence the target volumes for DEV would be /db/dev/p02 and /db/dev/p03
# 4. Standby database includes 3 standby redo logs
# 5. The script will create two sql files rename_files.gsql and drop_sby.gsql
#
#*******Disclaimer:*************************************************************
# This script is offered "as is" with no warranty.  While this script is
# tested and worked in my environment, it is recommended that you test
# this script in a test lab before using in a production environment.
# tested and worked in my environment, it is recommended that you test
# this script in a test lab before using in a production environment.
# No written permission needed to use this script but me or Pure Storage
# will not be liable for any damage or loss to the system.
#*******************************************************************************/

set lines 132
set head off
set echo off
set veri off
set feed off
set term off
spool rename_files.gsql
prompt set veri off
prompt set echo off
prompt set feed off
prompt set term off
select 'alter database rename file '''||
        name||''' to '''||
        '/db/'||'&1'||substr(name,1,instr(name,'prod_sby')-1) ||'&&1'||substr(name,instr(name,'prod_sby')+8) ||''';'
  from v$datafile;
select 'alter database rename file '''||
        name||''' to '''||
        '/db/'||'&&1'||substr(name,1,instr(name,'prod_sby')-1) ||'&&1'||substr(name,instr(name,'prod_sby')+8) ||''';'
  from v$tempfile;
select 'alter database rename file '''||member||''' to '''||
       '/db/'||'&&1'||substr(member,1,instr(member,'prod_sby')-1) ||'&&1'||substr(member,instr(member,'prod_sby')+8) ||''';'
  from v$logfile
 where type != 'STANDBY';

spool drop_sby.gsql
select 'alter database drop standby logfile '''||member||''';'
  from v$logfile
 where type = 'STANDBY';
spool off
prompt set term on
