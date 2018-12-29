#!/bin/bash
 
# By: cadi
# 自动化安装 openssh openssl wget
# ZIP文件需要传到root目录中。
# 运行脚本必须要root用户。
# 运行规则 sh openssh_openssl_init.sh
# description:openssh openssl bash glibc ntp wget init update


Zlibv=`ls /root/openssl_up/zlib-*.tar.gz | awk -F/ '{print $4}' |awk -F.tar '{print $1}'`
Opensslv=`ls /root/openssl_up/openssl-*.tar.gz | awk -F/ '{print $4}' |awk -F.tar '{print $1}'`
Opensshv=`ls /root/openssl_up/openssh-*.tar.gz | awk -F/ '{print $4}' |awk -F.tar '{print $1}'`
Wgetv=`ls /root/openssl_up/wget-*.tar.gz | awk -F/ '{print $4}' |awk -F.tar '{print $1}'`
UJ=`awk '/processor/{i++}END{print i}' /proc/cpuinfo`
Adir=/root/openssl_up


#检测当前用户是否是root用户
if [[ "$(whoami)" != "root" ]]; then
  
    echo "please run this script as root ." >&2
    exit;
fi

sed -i '/SELINUX/s/enforcing/disabled/' /etc/selinux/config
setenforce 0
systemctl stop postfix.service
systemctl disable postfix.service

systemctl stop firewalld.service
systemctl disable firewalld.service

/sbin/service sshd stop
yum -y install openssl-devel
yum -y remove openssh


#install zlib
mkdir -p /usr/local/zlib
cd $Adir
tar zxvf $Zlibv.tar.gz 
cd $Adir/$Zlibv
./configure --prefix=/usr/local/zlib
make -j$UJ && make install

#install openssl
mkdir -p /usr/local/openssl
cd $Adir
tar zxvf $Opensslv.tar.gz
cd $Adir/$Opensslv
./config --prefix=/usr/local/openssl -fPIC no-gost && make -j$UJ depend && make install
\mv /usr/bin/openssl /usr/bin/openssl.old
\mv /usr/include/openssl /usr/include/openssl.old
ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
ln -s /usr/local/openssl/include/openssl /usr/include/openssl
echo "/usr/local/openssl/lib" >> /etc/ld.so.conf
/sbin/ldconfig -v
openssl version -a | awk 'NR==1' > $Adir/openssl_up.log

#install ssh
\mv /etc/ssh /etc/ssh.old
cd $Adir
tar -zxvf $Opensshv.tar.gz
cd $Adir/$Opensshv
./configure --prefix=/usr --sysconfdir=/etc/ssh  --with-zlib=/usr/local/zlib --with-ssl-dir=/usr/local/openssl  --with-md5-passwords --mandir=/usr/share/man && make -j$UJ && make install
ssh -V 


\cp -p contrib/redhat/sshd.init /etc/init.d/sshd
chmod +x /etc/init.d/sshd
sed -i 's@/sbin/restorecon /etc/ssh/ssh_host_key.pub@#/sbin/restorecon /etc/ssh/ssh_host_key.pub@' /etc/init.d/sshd 
chkconfig --add sshd
\cp sshd_config /etc/ssh/sshd_config
\cp sshd /usr/sbin/sshd
service sshd start
ssh -V


#centos 7.2不需要升级glibc和bash，如果没装ntp服务器端，也不用升级ntp，下面升级wget

#install wget
cd $Adir
mkdir -p /usr/local/wget
tar xvf $Wgetv.tar.gz
cd $Adir/$Wgetv
./configure --with-ssl=openssl && make -j$UJ && make install
\cp /usr/local/wget/src/wget /usr/bin/wget
wget --version | awk 'NR==1' >> $Adir/openssl_up.log



sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
#sed -i 's/#GSSAPIAuthentication no$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#UseDNS no/UseDNS no/' /etc/ssh/sshd_config
sed -i 's/#Port 22/Port 32200/' /etc/ssh/sshd_config
echo 'Protocol 2' >> /etc/ssh/sshd_config
#sed -i '/^#UsePAM no/a UsePAM yes' /etc/ssh/sshd_config
service sshd restart
#如果重启失败，多半是selinux没关，或者防火墙端口没放行