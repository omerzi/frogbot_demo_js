MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

sed -i '/^KUBELET_EXTRA_ARGS=/a KUBELET_EXTRA_ARGS+=" --eviction-hard memory.available<1Gi --eviction-soft memory.available<2Gi --eviction-soft-grace-period memory.available=2m0s --kube-reserved cpu=500m,memory=9000Mi --system-reserved cpu=500m,memory=1000Mi --register-with-taints=app_type=xray-jobs:NoSchedule"' /etc/eks/bootstrap.sh

yum install -y iptables-services
iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP
iptables-save | tee /etc/sysconfig/iptables
systemctl enable --now iptables

echo "You are accessing a private information system that may contain U.S. Government data. All information on this computer system may be monitored, intercepted, recorded, read, copied, audited, and disclosed by and to authorized personnel for official purposes, including criminal investigations. Access to and use of this system is not approved for general public access. Unauthorized use of the system or its data is prohibited and may subject violators to criminal, civil, and/or administrative action. Any access attempts or use of this computer system by any person, whether authorized or unauthorized, constitutes consent to these terms." | sudo tee /etc/fedramp
sudo sed -i 's,#Banner none,Banner /etc/fedramp,' /etc/ssh/sshd_config

mkdir -p /tmp/anitian
yum install awscli -y
mkdir -p ~/.aws
aws s3 cp s3://${anitian_s3}/shared/install/jfrog-trend-linux-install.sh /tmp/anitian/ --region us-gov-west-1
aws s3 cp s3://${anitian_s3}/shared/install/linux-install.sh /tmp/anitian/ --region us-gov-west-1
aws s3 cp s3://${anitian_s3}/shared/install/qualys-cloud-agent-rhel.sh /tmp/anitian/ --region us-gov-west-1
chmod +x /tmp/anitian/*.sh

echo "@reboot /tmp/anitian/linux-install.sh" | crontab - 
crontab -l|sed "\$a@reboot /tmp/anitian/qualys-cloud-agent-rhel.sh" | crontab - 
crontab -l|sed "\$a@reboot /tmp/anitian/jfrog-trend-linux-install.sh" | crontab - 

passwd=$(aws secretsmanager get-secret-value --secret-id ec2/anitian/usr --query SecretString --output text --region us-gov-west-1 | cut -d: -f2 | tr -d \"})
sudo useradd -m -p $passwd -s /bin/bash anitian
sudo usermod -a -G sudo anitian
passwd=
echo "anitian  ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/anitian
sudo su - anitian
cd /home/anitian
mkdir .ssh
chmod 700 .ssh
echo "${anitian_sshkey}" > .ssh/authorized_keys
chmod 600 .ssh/authorized_keys
sudo chown -R anitian:ec2-user .ssh

/sbin/grubby --update-kernel=ALL --args="fips=1"
/sbin/shutdown -r 2

--==MYBOUNDARY==--\