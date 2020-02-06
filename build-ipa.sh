#!/usr/bin/env bash
set -ex

TMPDIR=$(mktemp -d -p /var/tmp)
TMPDIR_RAMDISK=$(mktemp -d -p /var/tmp)
IPA_RAMDISK_VERSION=$(rpm -q --queryformat "%{VERSION}-%{RELEASE}" rhosp-director-images-ipa-x86_64)

chmod 755 $TMPDIR $TMPDIR_RAMDISK
cd $TMPDIR
tar -xf /usr/share/rhosp-director-images/ironic-python-agent-${IPA_RAMDISK_VERSION}.$(uname -m).tar
cd $TMPDIR_RAMDISK
/usr/lib/dracut/skipcpio $TMPDIR/ironic-python-agent.initramfs | zcat | cpio -ivd
# NOTE(elfosardo) we could inject a list of packages that we want to add, based
# on what we download in the main image and call this part only if we actually
# have packages in the list.
# Also version tagging is something we should consider.
# And cookies.
rpm2cpio /tmp/packages/openstack-ironic-python-agent*.rpm | cpio -ivdum
rpm2cpio /tmp/packages/python3-ironic-python-agent*.rpm | cpio -ivdum
rpm2cpio /tmp/packages/python3-ironic-lib*.rpm | cpio -ivdum

# Update netconfig to use MAC for DUID/IAID combo (same as RHCOS)
# FIXME: we need an alternative of this packaged
mkdir -p etc/NetworkManager/conf.d etc/NetworkManager/dispatcher.d
echo -e '[main]\ndhcp=dhclient\n[connection]\nipv6.dhcp-duid=ll' > etc/NetworkManager/conf.d/clientid.conf
echo -e '[[ "$DHCP6_FQDN_FQDN" =~ - ]] && hostname $DHCP6_FQDN_FQDN' > etc/NetworkManager/dispatcher.d/01-hostname
chmod +x etc/NetworkManager/dispatcher.d/01-hostname

find . 2>/dev/null | cpio -c -o | gzip -8  > /var/tmp/ironic-python-agent.initramfs
cp $TMPDIR/ironic-python-agent.kernel /var/tmp/
cd /var/tmp
ls -la
rm -fr $TMPDIR $TMPDIR_RAMDISK
