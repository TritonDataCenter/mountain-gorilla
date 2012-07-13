This dir holds the scripts from/for
<https://hub.joyent.com/wiki/display/dev/JIRA+Sprint+Release+Process>.

These scripts require jira.sh (included here in the repo), see
<https://bobswift.atlassian.net/wiki/display/JCLI/JIRA+Command+Line+Interface>.


# Prereqs

Ensure you have auth setup. You need a "~/.jiraclirc" file like this:

    --user joe.blow --password password

If your password has shell chars in it, tough luck.


# Usage

1. release the old version:

        ./releaseversion.sh "2012-07-12 Rainier"

2. add the next version (if not done earlier):

        ./addsprintversion.sh "2012-07-26 Snowball-II"

3. archive the old version. Note that archiving the version means that
   devs can't remove that version from tickets they are pushing to the new
   release now. That's a PITA, so suggest only doing this later on.

        ./archiveversion.sh "2012-07-12 Rainier"

