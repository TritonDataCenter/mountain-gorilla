#!/bin/bash

# Check if version name was supplied as parameter to script
if [ -z "$1" ];
  then echo "Provide NEW_VERSION name and RELEASE_DATE on command line, e.g. $0 \"2012-03-22 Jimbo\" \"3/22/12\". Exiting ..."; exit
  else NEW_VERSION=$1; RELEASE_DATE=$2
fi

# Assumes your username/password and server are all set in your jira.sh script
echo "This script will need updating if new projects are added to Jira"
echo "This script should be called with the Version you wish to add. i.e. $0 \"New Version\""
echo  "The version that will be added to all Jira projects is $NEW_VERSION, with a release date of $RELEASE_DATE"
echo "I will sleep for 5 secs so CTRL C if this is not what you wanted!"
echo
sleep 5

for project in ADMINUI AGENT BILLING CAPI PUBAPI DATASET DOC HVM HEAD INTRO MON NET OS PROV QA RELENG STOR PORTAL TOOLS DSAPI CNAPI DAPI FWAPI NAPI ZAPI MANTA WORKFLOW DCAPI CONSOLEAPI IMGAPI
do
  echo "Adding new version: $NEW_VERSION to Jira project: $project with release date $RELEASE_DATE"
#  echo "jira.sh --action addVersion  --project $project  --name $NEW_VERSION --date $RELEASE_DATE"
  jira.sh --action addVersion  --project $project  --name "$NEW_VERSION" --date "$RELEASE_DATE"
  sleep 5
done
