#*******************************************************************************
# Script: pureclone.py
# Author: Somu Rajarathinam (somu)
# Date  : 2019-08-07
#
# Purpose: Python script for cloning source volume(s) into target volume(s)
#
# Usage: pureclone.py --array <FlashArray>  --user <FA username> --password <password>
#            [--srcPG <source PG name> | --srcVols <source volume list> ]
#            --tgtVols <target volume list> --suffix <snapshot suffix>
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
#!/usr/bin/python

import os
import sys
import purestorage
import time
import datetime
import collections
import requests
import argparse
import urllib3
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def die(msg):
  print("%s"% msg)
  sys.exit(-1)

parser = argparse.ArgumentParser(description='Oracle Database cloning script')

srcgroup = parser.add_mutually_exclusive_group(required=True)
tgtgroup = parser.add_mutually_exclusive_group(required=True)

parser.add_argument('--array', help='FlashArray Hostname or IP address', required=True)
parser.add_argument('--user', help='Username to connect to the FlashArray', default="pureuser")
parser.add_argument('--password',help='Password to connect to the FlashArray', action="store", default="pureuser")

srcgroup.add_argument('--srcVols',help='List of volumes that makes up source DB', action='store')
srcgroup.add_argument('--srcPG',help='Protection Group that makes up source DB', action='store')

tgtgroup.add_argument('--tgtVols',help='List of volumes on which source volumes to be cloned', action='store')

parser.add_argument('--suffix', help='Suffix for Source Volume snapshot', action="store", required=True)

args = vars(parser.parse_args())

# Connect to the Array
try:
  array = purestorage.FlashArray(args['array'],args['user'],args['password'])
except ValueError:
  die("Error in connecting to the Array.  Check credentials or the REST version !!")
except Exception as err:
  print("Error in connecting to the Array!! ")
  die(err)


# Extract Source Volumes
if args['srcPG']:
    try:
       spg = array.get_pgroup(args['srcPG']);
       srcVols = spg['volumes']
    except Exception as err:
       print("Source Protection Group Error !!")
       die(err)
else:
  srcVols=args['srcVols'].split(",")
  for vol in srcVols:
    try:
       sv = array.get_volume(vol)
    except Exception as err:
      print("Volume " + vol + " not found !!")
      die(err)

#for vol in srcVols:
#    print "%s" % vol

# Extract Target volumes
tgtVols=args['tgtVols'].split(",")

#for vol in tgtVols:
#    print "%s" % vol

# Verify source volumes count matches with target volumes
if len(srcVols) != len(tgtVols):
  die("Mismatch on Source and Target volume counts! ")

# Verify no source volume is included in the target list
if srcVols == tgtVols:
  die("Source and Target volumes cannot be same !")

for vol in srcVols:
  if vol in tgtVols:
    die("Source volume(s) cannot be included in the Target volumes!")
# This might be not true for Replicated environment - Not relevant for local

# Check if the same volume name is included more than once
# find and list duplicates in a list
dup=[item for item, count in collections.Counter(tgtVols).items() if count > 1]
if dup:
  die("Same volume cannot be included more than once in the target volume list")

sfx=args['suffix']

# Take FlashRecover Snapshot
if args['srcPG']:
# print args['srcPG']
# try:
  pg=args['srcPG']+'.'+sfx
  for i in range(0,len(srcVols)):
    #print("Source vol %s and Target vol %s"% (pg+'.'+srcVols[i],tgtVols[i]))
    ret=array.copy_volume(pg+'.'+srcVols[i],tgtVols[i],overwrite="true")
    print ret['name'] + " Serial: " + ret['serial']

else:
# Copy Snapshot on to target volumes
  for i in range(0,len(srcVols)):
    srcvol=srcVols[i]+'.'+sfx
    #print("Source vol %s and Target vol %s"% (srcvol,tgtVols[i]))
    ret=array.copy_volume(srcvol,tgtVols[i],overwrite="true")
    print ret['name'] + " Serial: " + ret['serial']
array.invalidate_cookie()
