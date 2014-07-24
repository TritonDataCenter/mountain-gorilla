#!/bin/bash
#
# Update a new sprint version to all (non-archived) devhub Jira projects.
#
# Usage:
#   ./addsprintversion.sh VERSION
#
# Example:
#   ./addsprintversion.sh '2011-12-29 Duffman'
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


if [[ -z "$1" ]]; then
    echo "Provide NEW_VERSION name, e.g. $0 '2012-03-22 Jimbo'";
    exit 1
fi
NEW_VERSION=$1

YEAR=$(echo $NEW_VERSION | cut -c 3-4)
MONTH=$(echo $NEW_VERSION | cut -c 6-7)
DAY=$(echo $NEW_VERSION | cut -c 9-10)
RELEASE_DATE=$MONTH/$DAY/$YEAR


echo "This will add the new version '$NEW_VERSION' with release date '$RELEASE_DATE' for all devhub Jira projects."
read -p "Hit Enter to continue..."
echo

PROJECTS=$(./jira.sh `cat ~/.jiraclirc` --action getProjectList --server https://devhub.joyent.com/jira \
    | python -c "import sys, csv; rows = list(csv.reader(sys.stdin)); projects = ['%s  %s' % (r[0], r[2]) for r in rows[2:] if r]; print '\n'.join(projects)" \
    | grep -v Archived \
    | grep -v '^\(DCOPS\|OPS\|CM\|ELBAPI\|INC\|NETOPS\)$' \
    | cut -d' ' -f1 | xargs)

for project in $PROJECTS
do
  echo "# $project: add new version '$NEW_VERSION' with release date '$RELEASE_DATE'"
  $TOP/jira.sh $JIRACLI_OPTS --action addVersion  \
    --project $project  --name "$NEW_VERSION" --date "$RELEASE_DATE" || true
done
