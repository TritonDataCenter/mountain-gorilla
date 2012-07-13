#!/bin/bash

# Check if version name was supplied as parameter to script
if [ -z "$1" ];
  then echo "Provide ARCHIVE_VERSION name on command line, e.g. $0 \"2012-03-22 Jimbo\" Exiting ..."; exit
  else ARCHIVE_VERSION=$1
fi

# Assumes your username/password and server are all set in your jira.sh script
echo "This script will need updating if new projects are added to Jira"
echo "This script should be called with the Version you wish to archive. i.e. $0 \"Archive Version\""
echo  "The version that will be archived from all Jira projects is $ARCHIVE_VERSION, I will sleep for 5 secs so CTRL C if this is not what you wanted!"
echo
sleep 5

for project in ADMINUI AGENT BILLING CAPI PUBAPI DATASET DOC HVM HEAD INTRO MON NET OS PROV QA RELENG STOR PORTAL TOOLS DSAPI CNAPI DAPI FWAPI NAPI ZAPI MANTA WORKFLOW DCAPI CONSOLEAPI IMGAPI
do
  echo "Archiving version: $ARCHIVE_VERSION for Jira project: $project"
  jira.sh --action archiveVersion  --project $project  --name "$ARCHIVE_VERSION" 
  sleep 5
done
