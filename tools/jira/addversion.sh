#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

#
# Update a new version to all (non-archived) devhub Jira projects.
#
# Usage:
#   ./addversion.sh VERSION
#
# Example:
#   ./addversion.sh '6.5.4 OS Update 2'
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
    echo "Provide NEW_VERSION name, e.g. $0 '6.5.4 OS Update 2'";
    exit 1
fi
NEW_VERSION=$1


echo "This will add the new version '$NEW_VERSION' for all devhub Jira projects."
read -p "Hit Enter to continue..."
echo

PROJECTS=$(./jira.sh `cat ~/.jiraclirc` --action getProjectList --server https://devhub.joyent.com/jira \
    | python -c "import sys, csv; rows = list(csv.reader(sys.stdin)); projects = ['%s  %s' % (r[0], r[2]) for r in rows[2:] if r]; print '\n'.join(projects)" \
    | grep -v Archived | cut -d' ' -f1 | xargs)

for project in $PROJECTS
do
  echo "# $project: add new version '$NEW_VERSION'"
  $TOP/jira.sh $JIRACLI_OPTS --action addVersion  \
    --project $project  --name "$NEW_VERSION" || true
done
