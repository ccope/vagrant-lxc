#!/bin/bash

#set -x
set -e
# Script used to build centos base vagrant-lxc containers, currently limited to
# host's arch
#
# USAGE:
#   $ cd boxes && sudo ./build-centos-box.sh centos_RELEASE
#
# To enable Chef or any other configuration management tool pass '1' to the
# corresponding env var:
#   $ CHEF=1 sudo -E ./build-centos-box.sh centos_RELEASE
#   $ PUPPET=1 sudo -E ./build-centos-box.sh centos_RELEASE
#   $ SALT=1 sudo -E ./build-centos-box.sh centos_RELEASE
#   $ BABUSHKA=1 sudo -E ./build-centos-box.sh centos_RELEASE

##################################################################################
# 0 - Initial setup and sanity checks
TODAY=$(date -u +"%Y-%m-%d")
NOW=$(date -u)
DISTRO="centos"
RELEASE=${1:-"5"}
ARCH=$(arch)
if [ ${ARCH} == "x86_64" ]
then
    ARCH="x86-64"
else
    ARCH=$ARCH
fi
PKG=vagrant-lxc-${DISTRO}-${RELEASE}-${ARCH}-${TODAY}.box
WORKING_DIR=/tmp/vagrant-lxc-${DISTRO}-${RELEASE}-${ARCH}
VAGRANT_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key"
ROOTFS=/var/lib/lxc/${DISTRO}-${RELEASE}-${ARCH}-base/rootfs

# Path to files bundled with the box
CWD=`readlink -f .`
LXC_TEMPLATE=${CWD}/centos/lxc-template
LXC_CONF=${CWD}/common/lxc.conf
METATADA_JSON=${CWD}/common/metadata.json

# Set up a working dir
mkdir -p $WORKING_DIR

if [ -f "${WORKING_DIR}/${PKG}" ]; then
  echo "Found a box on ${WORKING_DIR}/${PKG} already!"
  exit 1
fi

if [ -f "/tmp/CENTOS5_64.tar.xz" ]; then
    echo "Centos FAI image already exists"
else
    echo "Downloading image..."
    wget http://fai-project.org/download/basefiles/CENTOS5_64.tar.xz -O /tmp/CENTOS5_64.tar.xz
fi

##################################################################################
# 1 - Create the base container

if $(lxc-ls | grep -q "${DISTRO}-${RELEASE}-${ARCH}-base"); then
  echo "Base container already exists, please remove it with \`lxc-destroy -n ${DISTRO}-${RELEASE}-${ARCH}-base\`!"
  exit 1
else
  export SUITE=${DISTRO}-${RELEASE}-${ARCH}
  lxc-create -n ${DISTRO}-${RELEASE}-${ARCH}-base -t centos #-- -d -F
fi

######################################
# 2 - Fix some known issues

##################################################################################
# 3 - Prepare vagrant user
#chroot ${ROOTFS} useradd -m vagrant -G wheel
#echo -n 'vagrant:vagrant' | chroot ${ROOTFS} chpasswd

##################################################################################
# 4 - Setup SSH access and passwordless sudo

# Configure SSH access
mkdir -p ${ROOTFS}/home/vagrant/.ssh
echo $VAGRANT_KEY > ${ROOTFS}/home/vagrant/.ssh/authorized_keys
chroot ${ROOTFS} chown -R vagrant: /home/vagrant/.ssh

# Enable passwordless sudo for users under the "sudo" group
echo "%wheel        ALL=(ALL)       NOPASSWD: ALL" >> ${ROOTFS}/etc/sudoers

##################################################################################
# 5 - Add some goodies and update packages

YUM="chroot ${ROOTFS} yum -y --nogpgcheck"
$YUM update
if [ $? -ne 0 ]; then
    return 1
fi

##################################################################################
# 6 - Configuration management tools

if [ $CHEF = 1 ]; then
  ./common/install-chef $ROOTFS
fi

if [ $PUPPET = 1 ]; then
  ./common/install-puppet $ROOTFS
fi

if [ $SALT = 1 ]; then
  ./common/install-salt $ROOTFS
fi

if [ $BABUSHKA = 1 ]; then
  ./common/install-babushka $ROOTFS
fi

##################################################################################
# 7 - Free up some disk space

rm -rf ${ROOTFS}/tmp/*
chroot ${ROOTFS} yum clean all

##################################################################################
# 8 - Build box package

# Compress container's rootfs
cd $(dirname $ROOTFS)
tar --numeric-owner -czf /tmp/vagrant-lxc-${DISTRO}-${RELEASE}-${ARCH}/rootfs.tar.gz ./rootfs/*

# Prepare package contents
cd $WORKING_DIR
cp $LXC_TEMPLATE .
cp $LXC_CONF .
cp $METATADA_JSON .
chmod +x lxc-template
sed -i "s/<TODAY>/${NOW}/" metadata.json

# Vagrant box!
tar -czf $PKG ./*

chmod +rw ${WORKING_DIR}/${PKG}
mkdir -p ${CWD}/output
mv ${WORKING_DIR}/${PKG} ${CWD}/output

# Clean up after ourselves
rm -rf ${WORKING_DIR}

echo "The base box was built successfully to ${CWD}/output/${PKG}"
