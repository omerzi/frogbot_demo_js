MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

sed -i '/^KUBELET_EXTRA_ARGS=/a KUBELET_EXTRA_ARGS+=" --eviction-hard memory.available<1Gi --eviction-soft memory.available<2Gi --eviction-soft-grace-period memory.available=2m0s --kube-reserved cpu=500m,memory=3000Mi --system-reserved cpu=500m,memory=4000Mi --register-with-taints=app_type=openebs:NoSchedule"' /etc/eks/bootstrap.sh

yum install iscsi-initiator-utils -y && sudo systemctl enable iscsid && sudo systemctl start iscsid 
yum install -y iptables-services
yum install iscsi-initiator-utils -y && systemctl enable iscsid && systemctl start iscsid 
iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP
iptables-save | tee /etc/sysconfig/iptables
systemctl enable --now iptables

--==MYBOUNDARY==--\