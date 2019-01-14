#!/bin/bash
 
# By: cadi
# 自动化升级 openssh openssl
# ZIP文件需要传到root目录中。
# 运行脚本必须要root用户。
# 运行规则 sh open_update.sh 端口

Opensslv=`ls /root/openssl_up/openssl-*.tar.gz | awk -F/ '{print $4}' |awk -F.tar '{print $1}'`
Opensshv=`ls /root/openssl_up/openssh-*.tar.gz | awk -F/ '{print $4}' |awk -F.tar '{print $1}'`
UJ=`awk '/processor/{i++}END{print i}' /proc/cpuinfo`
Adir=/root/openssl_up
PORT=$1
TIMEDATA=$(date +"%Y%m%d")

#检测当前用户是否是root用户
if [[ "$(whoami)" != "root" ]]; then
  
    echo "please run this script as root ." >&2
    exit;
fi

#检测是否输入端口
if [ "$PORT" = "" ]; then
	echo "Port is null"
	exit;
fi

#updata openssl
mkdir -p /usr/local/openssl
cd $Adir
tar zxvf $Opensslv.tar.gz
cd $Adir/$Opensslv
./config --prefix=/usr/local/openssl -fPIC no-gost && make -j$UJ depend && make install
\mv /usr/bin/openssl /usr/bin/openssl.$TIMEDATA
\mv /usr/include/openssl /usr/include/openssl.$TIMEDATA
ln -s /usr/local/openssl/bin/openssl /usr/bin/openssl
ln -s /usr/local/openssl/include/openssl /usr/include/openssl
echo "/usr/local/openssl/lib" >> /etc/ld.so.conf
/sbin/ldconfig -v
openssl version -a | awk 'NR==1' > $Adir/openssl_up.log



#updata ssh
\mv /etc/ssh /etc/ssh.$TIMEDATA
mkdir -p /etc/ssh
cd $Adir
tar -zxvf $Opensshv.tar.gz
cd $Adir/$Opensshv
#./configure --prefix=/usr --sysconfdir=/etc/ssh  --with-zlib=/usr/local/zlib --with-ssl-dir=/usr/local/openssl/include/openssl  --with-md5-passwords --disable-etc-default-login --with-ssl-engine --mandir=/usr/share/man && make -j$UJ && make install
./configure --prefix=/usr --sysconfdir=/etc/ssh --with-md5-passwords --with-ssl-dir=/usr/local/openssl --without-hardening && make -j$UJ && make install


\mv /etc/init.d/sshd /etc/init.d/sshd.$TIMEDATA
cp -p contrib/redhat/sshd.init /etc/init.d/sshd
chmod +x /etc/init.d/sshd
sed -i 's@/sbin/restorecon /etc/ssh/ssh_host_key.pub@#/sbin/restorecon /etc/ssh/ssh_host_key.pub@' /etc/init.d/sshd 
#chkconfig --add sshd
\cp sshd_config /etc/ssh/sshd_config
\cp sshd /usr/sbin/sshd

#修改配置
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords no/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sed -i 's/#UseDNS no/UseDNS no/' /etc/ssh/sshd_config
sed -i "s/#Port 22/Port $PORT/" /etc/ssh/sshd_config
echo 'Protocol 2' >> /etc/ssh/sshd_config

service sshd restart
ssh -V