#!/bin/bash
cat << EOF > /etc/resolv.conf
nameserver 192.168.0.1
nameserver 8.8.8.8
nameserver 77.88.8.8
EOF
yum -y install epel-release
yum -y install dhcp tftp-server nginx wget curl
setenforce 0

cat >/etc/dhcp/dhcpd.conf <<EOF
option space pxelinux;
option pxelinux.magic code 208 = string;
option pxelinux.configfile code 209 = text;
option pxelinux.pathprefix code 210 = text;
option pxelinux.reboottime code 211 = unsigned integer 32;
option architecture-type code 93 = unsigned integer 16;
subnet 10.0.0.0 netmask 255.255.255.0 {

	range 10.0.0.100 10.0.0.120;
	class "pxeclients" {
	  match if substring (option vendor-class-identifier, 0, 9) = "PXEClient";
	  next-server 10.0.0.20;

	  if option architecture-type = 00:07 {
	    filename "uefi/shim.efi";
	    } else {
	    filename "pxelinux/pxelinux.0";
	  }
	}
}
EOF

systemctl start dhcpd
systemctl start tftp.service

mkdir /var/lib/tftpboot/pxelinux

wget --no-check-certificate https://mirror.sale-dedic.com/centos/8.5.2111/BaseOS/x86_64/os/Packages/syslinux-tftpboot-6.04-5.el8.noarch.rpm
rpm2cpio syslinux-tftpboot-6.04-5.el8.noarch.rpm | cpio -dimv
\cp ./tftpboot/pxelinux.0 /var/lib/tftpboot/pxelinux
\cp ./tftpboot/libutil.c32 /var/lib/tftpboot/pxelinux
\cp ./tftpboot/menu.c32 /var/lib/tftpboot/pxelinux
\cp ./tftpboot/libmenu.c32 /var/lib/tftpboot/pxelinux
\cp ./tftpboot/ldlinux.c32 /var/lib/tftpboot/pxelinux
\cp ./tftpboot/vesamenu.c32 /var/lib/tftpboot/pxelinux

mkdir /var/lib/tftpboot/pxelinux/pxelinux.cfg
cat >/var/lib/tftpboot/pxelinux/pxelinux.cfg/default <<EOF
default menu
prompt 0
timeout 600



MENU PXE setup

LABEL linux
  menu label ^Install CentOS8
  menu default
  kernel images/CentOS-8.5/vmlinuz
  append initrd=images/CentOS-8.5/initrd.img ramdisk_size=128000 ip=dhcp inst.repo=http://10.0.0.20/ devfs=nomount
LABEL ks
  menu label ^Auto install system
  kernel images/CentOS-8.5/vmlinuz
  append initrd=images/CentOS-8.5/initrd.img ramdisk_size=128000 ip=dhcp inst.repo=http://10.0.0.20/ devfs=nomount ks=http://10.0.0.20/ks.cfg
LABEL vesa
  menu label Install system with ^basic video driver
  kernel images/CentOS-8.5/vmlinuz
  append initrd=images/CentOS-8.5/initrd.img ip=dhcp inst.xdriver=vesa nomodeset 
LABEL rescue
  menu label ^Rescue installed system
  kernel images/CentOS-8.5/vmlinuz
  append initrd=images/CentOS-8.5/initrd.img rescue
LABEL local
  menu label Boot from ^local drive
  localboot 0xffff
EOF

mkdir -p /var/lib/tftpboot/pxelinux/images/CentOS-8.5/
mkdir -p /mnt


wget --no-check-certificate https://mirror.sale-dedic.com/centos/8.5.2111/BaseOS/x86_64/os/images/pxeboot/initrd.img
wget --no-check-certificate https://mirror.sale-dedic.com/centos/8.5.2111/BaseOS/x86_64/os/images/pxeboot/vmlinuz
cp {vmlinuz,initrd.img} /var/lib/tftpboot/pxelinux/images/CentOS-8.5/
wget --no-check-certificate https://mirror.sale-dedic.com/centos/8.5.2111/isos/x86_64/CentOS-8.5.2111-x86_64-boot.iso

mount -t iso9660 CentOS-8.5.2111-x86_64-boot.iso /mnt -o loop,ro
rm -rf /usr/share/nginx/html/*
cp -vR  /mnt/* /usr/share/nginx/html/
cp /vagrant/ks.cfg /usr/share/nginx/html/
sed -i '42a\       autoindex on\;' /etc/nginx/nginx.conf
systemctl start nginx



