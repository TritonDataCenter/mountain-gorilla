A driver script and "user-script" to create a smartos-1.6.3 zone
and set it up for building all SDC components.

Usage:

1. Choose a butler name for your new Jenkins slave from
   <http://en.wikipedia.org/wiki/List_of_famous_fictional_butlers>.

2. Copy the two scripts in this dir somewhere in the GZ of the target machine.

3. Run this:

        ./mk-jenkins-slave.sh BUTLER-NAME [IMAGE-UUID]

4. Tail the setup log file (it takes a long time to run the user script):

        tail -f /zones/$UUID/root/var/svc/setup.log

