#!/bin/bash
#
# LICENSE: See lib/LICENSE.txt
#

if [[ -n "$TRACE" ]]; then
    export PS4='[\D{%FT%TZ}] ${BASH_SOURCE}:${LINENO}: ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
    set -o xtrace
fi
set -o errexit
set -o pipefail

# Comments
# - Customize for your installation, for instance you might want to add default parameters like the following:
# java -jar `dirname $0`/lib/jira-cli-2.6.0.jar --server http://my-server --user automation --password automation "$@"

java -jar `dirname $0`/lib/jira-cli-2.6.0.jar "$@"
