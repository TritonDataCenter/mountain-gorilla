#!/bin/bash
#
# Archive a version in all (non-archived) devhub Jira projects.
#
# Usage:
#   ./archiveversion.sh VERSION [PROJECTS...]
#
# Example:
#   ./archiveversion.sh '2011-12-29 Duffman'
#

set -e
#set -x
TOP=$(cd $(dirname "$0") >/dev/null; pwd)


JIRACLI_OPTS="--server https://devhub.joyent.com/jira"
JIRACLI_RC_PATH="$HOME/.jiraclirc"
if [ ! -f "$JIRACLI_RC_PATH" ]; then
    echo "'$JIRACLI_RC_PATH' does not exist. You need one that looks like this:"
    echo "    --user=joe.blow --password='his-jira-password'"
    exit 1
fi
JIRACLI_OPTS+=" $(cat $JIRACLI_RC_PATH)"


# Check if version name was supplied as parameter to script
if [[ -z "$1" ]]; then
    echo "Provide ARCHIVE_VERSION name, e.g. $0 '2012-03-22 Jimbo'";
    exit 1
fi
ARCHIVE_VERSION=$1
shift

PROJECTS=$*

echo "This will archive version '$ARCHIVE_VERSION' for devhub Jira projects."
read -p "Hit Enter to continue..."
echo

if [[ -z "$PROJECTS" ]]; then
    PROJECTS=$(./jira.sh `cat ~/.jiraclirc` --action getProjectList --server https://devhub.joyent.com/jira \
        | python -c "import sys, csv; rows = list(csv.reader(sys.stdin)); projects = ['%s  %s' % (r[0], r[2]) for r in rows[2:] if r]; print '\n'.join(projects)" \
        | grep -v Archived | cut -d' ' -f1 | xargs)
fi

for project in $PROJECTS
do
  echo "# $project: archive version '$ARCHIVE_VERSION'"
  $TOP/jira.sh $JIRACLI_OPTS --action archiveVersion  \
    --project $project  --name "$ARCHIVE_VERSION" || true
done
