MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="

--==MYBOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"

sed -i '/^KUBELET_EXTRA_ARGS=/a KUBELET_EXTRA_ARGS+=" --eviction-hard memory.available<1Gi --eviction-soft memory.available<2Gi --eviction-soft-grace-period memory.available=2m0s --kube-reserved cpu=500m,memory=9000Mi --system-reserved cpu=500m,memory=1000Mi --register-with-taints=pool_type=infra:NoSchedule"' /etc/eks/bootstrap.sh

yum install -y iptables-services
iptables --insert FORWARD 1 --in-interface eni+ --destination 169.254.169.254/32 --jump DROP
iptables-save | tee /etc/sysconfig/iptables
systemctl enable --now iptables

--==MYBOUNDARY==--\