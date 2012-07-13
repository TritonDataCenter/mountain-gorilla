#!/bin/bash
#
# Update devhub Jira projects to say a sprint release is "released".
#
# Usage:
#   ./releaseversion.sh VERSION
#
# Example:
#   ./releaseversion.sh '2011-12-29 Duffman'
#

set -e
#set -x
TOP=$(cd $(dirname "$0") >/dev/null; pwd)

# Check if version name was supplied as parameter to script
if [ -z "$1" ]; then
    echo "You must specify a version name e.g. '2011-12-29 Duffman' on the command line.";
    exit 1
fi
VERSION_TO_RELEASE=$1
SERVER=
JIRACLI_OPTS="--server https://devhub.joyent.com/jira"
JIRACLI_RC_PATH="$HOME/.jiraclirc"
if [ ! -f "$JIRACLI_RC_PATH" ]; then
    echo "'$JIRACLI_RC_PATH' does not exist. You need one that looks like this:"
    echo "    --user=joe.blow --password='his-jira-password'"
    exit 1
fi
JIRACLI_OPTS+=" $(cat $JIRACLI_RC_PATH)"

# Assumes your username/password and server are all set in your jira.sh script
echo "This will 'release' version '$VERSION_TO_RELEASE' for all devhub Jira projects."
read -p "Hit Enter to continue..."
echo

PROJECTS=$(./jira.sh `cat ~/.jiraclirc` --action getProjectList --server https://devhub.joyent.com/jira \
    | python -c "import sys, csv; rows = list(csv.reader(sys.stdin)); projects = ['%s  %s' % (r[0], r[2]) for r in rows[2:] if r]; print '\n'.join(projects)" \
    | grep -v Archived | cut -d' ' -f1 | xargs)

for project in $PROJECTS
do
  echo "# Releasing version '$VERSION_TO_RELEASE' for Jira project '$project'"
  #$TOP/jira.sh $JIRACLI_OPTS --action getIssue --issue MON-1   # testing auth
  $TOP/jira.sh $JIRACLI_OPTS --action releaseVersion  \
    --project $project  --name "$VERSION_TO_RELEASE"  || true
done
