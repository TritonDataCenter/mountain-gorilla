#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2016, Joyent, Inc.
#

#
# List the Joyent Engineering Jira projects.
# This definition is a little bit fluid.
#

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail


TOP=$(cd $(dirname "$0") >/dev/null; pwd)

JIRACLI_OPTS="--server https://devhub.joyent.com/jira"
JIRACLI_RC_PATH="$HOME/.jiraclirc"
if [ ! -f "$JIRACLI_RC_PATH" ]; then
    echo "'$JIRACLI_RC_PATH' does not exist. You need one that looks like this:"
    echo "    --user=joe.blow --password='his-jira-password'"
    exit 1
fi
JIRACLI_OPTS+=" $(cat $JIRACLI_RC_PATH)"


# Here we are blacklisting instead of whitelisting, on the theory that
# automatically adding versions to new projects is preferred.
PROJECTS=$($TOP/jira.sh $JIRACLI_OPTS --action getProjectList \
    | python -c "import sys, csv; rows = list(csv.reader(sys.stdin)); projects = ['%s  %s' % (r[0], r[2]) for r in rows[2:] if r]; print '\n'.join(projects)" \
    | grep -v Archived \
    | awk '{print $1}' \
    | grep -v '^\(BILLOPS\|CFB\|CM\|COMM\|DASH\|DCOPS\|ELBAPI\|INC\|INCDEV\|JPC\|KFC\|MKTG\|NETOPS\|OPS\|PM\|QA\|RICHMOND\|SOLENG\|STOR\|SWSUP\|SYSSCI\|VICTORY\|ZUORA\)$')
echo "$PROJECTS"