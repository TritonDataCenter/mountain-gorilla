#!/bin/bash
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#

#
# Copyright (c) 2014, Joyent, Inc.
#

set -o errexit
set -o xtrace

export HOME=/root
export PATH=/root/opt/node/bin:/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin

if [[ -f /root/.ssh/automation.id_rsa.pub ]]; then
    # already setup
    exit 0
fi

hostname=$1

if [[ -z ${hostname} ]]; then
    hostname=$(mdata-get slave_name)
fi

JENKINS_CREDS=$(mdata-get jenkins_creds)

if [[ -z ${hostname} ]]; then
    echo "Usage: $0 <hostname>" >&2
    exit 1
fi

echo "${hostname}" > /etc/nodename
sed -e "s/$(zonename)/${hostname}/" /etc/hosts > /etc/hosts.new \
    && mv /etc/hosts.new /etc/hosts

mkdir -p /root/.ssh
chmod 700 /root/.ssh

cat > /root/.ssh/automation.id_rsa.pub <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2s5twaK3yK3iEW1Ka1rCoE7pENen2ijsZpSCDTxeKL9gzXE/W5Hm7VEp2AY+POWE3sTVmLf+b+mc3+ABCq3UnZgMGgsfZuTmmzQYuWI3yH1m1m3PzOjxF4n+2jWwwZ9JAyuzxQFfch8WPzhoylHEbuIsLc8QKUkr+26VYEA4o3ztK3vwNQ6WqSIfl9zGEak2u6laSQH8AFwodZfamEXfgj4YfM23gDz382aJOVa5q6EnDK01/8yveOM9AxK52y4+40mpQJiBwUTRMtP1irB6sT/zXJCVBkwKAiZnYlb9jHEwU1sN2QOe9rh0LwxO3j0wQuy7FmAtFOqZQlDN5Bki7Q== automation@lab-www-00
EOF
chmod 644 /root/.ssh/automation.id_rsa.pub
ln -s /root/.ssh/automation.id_rsa.pub /root/.ssh/id_rsa.pub

mdata-get automation.id_rsa > /root/.ssh/automation.id_rsa
chmod 600 /root/.ssh/automation.id_rsa
ln -s /root/.ssh/automation.id_rsa /root/.ssh/id_rsa

cat >> /root/.ssh/known_hosts <<EOF
git.joyent.com,165.225.133.140 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5lZJiIxLoJPgAagmVdH5cYZxP+p3p2Q4EK+SYUrTNQV50z2UXCRMnkT2gBSlBIENefQd0+H3z2jzzsteNBudb+g/78adWx7nK7HCuBqXZ9fv6TR/LZ8Pg0u3u6+1OolMpspifxbO2RdgOY16+7A5b2SDH43xSSSjb+aoEvIbriLxFPifUcKlpw16XXktTWAppcMwiKRjyAyr1eDqVuyfDFOIK352jydLGTobkSnjkAkomwZjHoizFII2mGu7CpMZsDNyRaZP3Wr0MMNgZpLqkXH+HjxLe/DWb6cJE8uS86EyKKBJ0q7kpgQz864UnJ9N+eznzA1IdeNUmmnGvwTgUQ==
github.com,192.30.252.131 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
EOF
chmod 600 /root/.ssh/known_hosts

# Allow Jenkins in
cat >> /root/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA2rHvfbH+VSzSWEj6IdA91OYVCmOOnS2/2mekUYnpYUCM1tGVVY8JFet0fxIg0UDZPsreInbvM3rycej8hcVrPLDXHjgbAsjVhEdHjdDY5qJYM+5OsqWSmbK06NdqOhwhZ5QSaq6r1disNIBpZBrqeCIodmcSsYs36Gd64a0Fp8iPUUZ3Zjm7JSSGm9mYPpJMWpnddfbKbjLj4t79b2ecbWhGX2UB5BmKwwf9kjzJJS4+vCxoEJU5suEkfw6KF3KHXXN+j1hBwfJDFyrYyXiJhWOiqFs0x87BnERXGyJZE1UxrV32SYlu/rsg2cVF4lCLv/4IEAA1Z4wIWCuk8F9Tzw== molybdenum
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAn6QHOqxWJr9Ice+fsqGPiURLgEOSWPt7slo1JkfncBLTlEswk/QpI36zepystMfrYq5kHNdgml3IivPgGLzLX3faNGup5z9dhFxv0Q9sX7WpDhtQNBhd9JZHX9x5PEDHq+bHpHmtJ6zDNfTkeH7Z+3pd9szVKxsSrRB96I2tB5hF4QQo4uv5H1Ljbk7+2mBlzEHxBnW3SYHgppLiADIaMolosYSPG/iIqORx9PRhAPXvu1pvvp5CTiWwvepq/S9/2dX/9acYvOo/0Ub0PY7uG+Do8dA1Nea7i4qH9L+iFNdpE95SQMPlNBSXU20YpMvKdrIUpnk4ojHw2l24uq9Lfw== trent.mick@joyent.com
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAqkeeWZHqiTNGGJJhyHJkD6LdmDsn30cPaJUzyt5Xu8U9j8Q/2WlkfC7ZVOwVBlDY4zNYsJZvrUB/xyN0QYrDXFVJ4fk+GNpCjCyTaZMq6HPtesB+vfWxe9DNcu+4QzEVy1Jrrw0S/fMk8IA3RXkwirQlGe5pmifxd8w+dyWZiiwE+5hiJcYo/XSPvzZxkayJDwST/WEBt9qGvTqWomFdVCn3W/BmWZILPPN6oE49v/yEp+h3DCcPLG/rYepeukto6wBfbGnHrQ2Uca6XLANtVv7L7KtT5gV6YdNWj5/N/bsCCO4dhPdygpZZOgZbR2v03w6iioAfCoR6dN60ssO6tw== joshw@Josh-Wilsdons-MacBook-Pro.local
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAs5xKh88/HuL+lr+i3DRUzcpkx5Ebbfq7NZVbjVZiICkhn6oCV60OGFmT5qsC2KTVyilakjU5tFlLSSNLQPbYs+hA2Q5tsrXx9JEUg/pfDQdfFjD2Rqhi3hMg7JUWxr9W3HaUtmnMCyrnJhgjA3RKfiZzY/Fkt8zEmRd8SZio0ypAI1IBTxpeaBQ217YqthKzhYlMh7pj9PIwRh7V0G1yDOCOoOR6SYCdOYYwiAosfFSMA2eMST4pjhnJTvrHMBOSn77lJ1hYPesjfjx/VpWIMYCzcP6mBLWaNGuJAIJMAk2EdNwO6tNoicQOH07ZJ4SbJcw6pv54EICxsaFnv0NZMQ== orlando@azathoth.local
EOF
chmod 600 /root/.ssh/authorized_keys

# Stupid Java will ask us for license otherwise.
mkdir -p /opt/local
touch /opt/local/.dlj_license_accepted

IS_163=0
IMAGE_UUID=$(mdata-get sdc:image_uuid)

if [[ ${IMAGE_UUID} == "01b2c898-945f-11e1-a523-af1afbe22822" || ${IMAGE_UUID} == "fd2cc906-8938-11e3-beab-4359c665ac99" ]]; then
    # smartos-1.6.3 force binutils to install first, this preempts gcc-tools from breaking us
    pkgin -y install binutils
    IS_163=1
fi

pkgin -y install $(pkgin search sun | grep ^sun-j[dr][ke] | cut -d ' ' -f1 | xargs) || /bin/true

# scmgit, gcc-*, gmake: needed by most parts of sdc build
# png, GeoIP, GeoLiteCity, ghostscript: cloud-analytics (CA)
# cscope: I (Trent) believe this is just for CA dev work
# python26: many parts of the build for javascriptlint
# zookeeper-client: binder needs this
# postgres client: needed by manta
# gsharutils: needed by manta
#
# Note: ignore failures here because one some newer images the package names
# differ. E.g. no such postgresql client package version on multiarch.
pkgin -y install gcc47 gcc-compiler gcc-runtime gcc-tools cscope gmake \
     scmgit python26 png GeoIP GeoLiteCity ghostscript zookeeper-client \
     binutils postgresql91-client-9.1.2 gsharutils build-essential \
     cdrtools \
     || /bin/true


# Download our own (sdc) node 0.10
pkgin -y rm nodejs || /bin/true

mkdir -p ~/opt

if [[ ${IMAGE_UUID} == "01b2c898-945f-11e1-a523-af1afbe22822" ||    # old
      ${IMAGE_UUID} == "fd2cc906-8938-11e3-beab-4359c665ac99" ||    # sdc-smartos-1.6.3
      ${IMAGE_UUID} == "de411e86-548d-11e4-a4b7-3bb60478632a"       # sdc-base-14.2.0
   ]]; then
    # If smartos-1.6.3
    NODEURL=https://download.joyent.com/pub/build/sdcnode/fd2cc906-8938-11e3-beab-4359c665ac99/master-20141010T195119Z/sdcnode/sdcnode-v0.10.26-zone-fd2cc906-8938-11e3-beab-4359c665ac99-master-20141010T171234Z-gcca0a36.tgz
    #NODEURL=https://download.joyent.com/pub/build/sdcnode/fd2cc906-8938-11e3-beab-4359c665ac99/master-latest/sdcnode/sdcnode-v0.10.26-zone-fd2cc906-8938-11e3-beab-4359c665ac99-master-20140623T210420Z-g28c7f9f.tgz
    cd ~/opt && curl $NODEURL | tar zxvf -
else
    # If multiarch
    NODEURL=https://download.joyent.com/pub/build/sdcnode/b4bdc598-8939-11e3-bea4-8341f6861379/master-latest/sdcnode/sdcnode-v0.10.26-zone64-b4bdc598-8939-11e3-bea4-8341f6861379-master-20140623T210418Z-g28c7f9f.tgz
    cd ~/opt && curl $NODEURL | tar zxvf -
fi

/root/opt/node/bin/node /root/opt/node/lib/node_modules/npm/cli.js install -gf npm

git config --global user.name "Jenkins Slave"
git config --global user.email jenkins-slave@joyent.com


# Get npm working with the old old node and npm by default in
# smartos/1.6.3. This avoids a CERT problem to the registry.
cat > /root/.npmrc <<EOF
registry = http://registry.npmjs.org/
EOF

# Need 'updates-imgadm' from imgapi-cli.git on the PATH (this is used
# by the MG builds to publish build images to updates.joyent.com).
mkdir -p /root/opt
(cd /root/opt \
    && git clone git@git.joyent.com:imgapi-cli.git \
    && cd imgapi-cli \
    && NODE_PREBUILT_CC_VERSION=4.6.2 PATH=/root/opt/node/bin:/opt/local/bin:/opt/local/gnu/bin:$PATH gmake)
echo '' >>/root/.bashrc
echo "export PATH=/root/opt/imgapi-cli/bin:$PATH" >>/root/.bashrc

if [[ ${IS_163} -eq 0 ]]; then
    # Do the smartos-live setup
    mkdir -p /root/tmp
    cd /root/tmp
    # Note: This "./configure" step is necessary to setup your system.
    git clone https://github.com/joyent/smartos-live.git
    cd smartos-live
    curl -k -O https://download.joyent.com/pub/build/configure.joyent
    GIT_SSL_NO_VERIFY=true ./configure
    cd /root
    rm -rf /root/tmp
fi

sed -i "s/^export PATH=/export PATH=\\/root\\/opt\\/node\\/bin:/g" ~/.bashrc

# setup some tunables and a /root/bin/startup.sh script so we can run stuff at boot.

mkdir -p /root/bin
cat > /root/bin/startup.sh <<EOF
#!/bin/bash
#
# This script runs from the application/jenkins-slave service on every boot.
#

set -o xtrace
set -o errexit

. /lib/svc/share/smf_include.sh

# Tune TCP so we will work better with Manta (borrowed from IMGAPI per TOOLS-364)
# '|| true' because this 'ipadm set-prop' is necessary on some platform versions
# and breaks on older ones.
ipadm set-prop -t -p max_buf=2097152 tcp || true
ndd -set /dev/tcp tcp_recv_hiwat 2097152
ndd -set /dev/tcp tcp_xmit_hiwat 2097152
ndd -set /dev/tcp tcp_conn_req_max_q 2048
ndd -set /dev/tcp tcp_conn_req_max_q0 8192

# Grr. for some reason DNS doesn't work right after startup.
# XXX figure it out!
retries=60
while [[ \${retries} -gt 0 ]]; do
    if ping www.google.com; then
        break;
    fi
    retries=\$((\${retries} - 1))
    sleep 1
done
[[ \${retries} -eq 0 ]] && exit 1

export GIT_SSL_NO_VERIFY=true
export PATH=/root/opt/node/bin:/root/opt/imgapi-cli/bin:/opt/local/bin:/opt/local/sbin:/usr/bin:/usr/sbin
export HOME=/root
export JENKINS_IP_ADDR=\$(/usr/sbin/mdata-get sdc:nics.0.ip)

mkdir -p /root/data/jenkins
curl -z /root/data/jenkins/slave.jar \
    -o /root/data/jenkins/slave.jar \
    -k https://jenkins.joyent.us/jnlpJars/slave.jar
rm -f /root/data/jenkins/slave.jnlp
curl -k -o /root/data/jenkins/slave.jnlp \
    https://${JENKINS_CREDS}@jenkins.joyent.us/computer/${hostname}/slave-agent.jnlp

nohup /opt/local/bin/java -jar /root/data/jenkins/slave.jar \
    -noCertificateCheck \
    -jnlpUrl file:///root/data/jenkins/slave.jnlp \
    2>&1 &

exit \${SMF_EXIT_OK}
EOF
chmod 755 /root/bin/startup.sh


cat > /tmp/jenkins-slave-startup.xml <<EOF
<?xml version='1.0'?>
<!DOCTYPE service_bundle SYSTEM '/usr/share/lib/xml/dtd/service_bundle.dtd.1'>
<service_bundle type='manifest' name='export'>
  <service name='application/jenkins-slave' type='service' version='0'>
    <create_default_instance enabled='true'/>
    <single_instance/>
    <dependency name='multi-user' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/milestone/multi-user:default'/>
    </dependency>
    <dependency name='net-phys' grouping='require_all' restart_on='none' type='service'>
      <service_fmri value='svc:/network/physical:default'/>
    </dependency>
    <exec_method name='start' type='method' exec='/root/bin/startup.sh' timeout_seconds='360'>
      <method_context>
        <method_credential user='root'/>
      </method_context>
    </exec_method>
    <exec_method name='stop' type='method' exec=':kill' timeout_seconds='60'/>
    <property_group name='application' type='application'/>
  </service>
</service_bundle>
EOF
svccfg import /tmp/jenkins-slave-startup.xml

# reboot
(sleep 20 ; reboot) &

exit 0

