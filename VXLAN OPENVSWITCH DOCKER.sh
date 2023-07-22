#######################-host 1 & 2-#######################
cat /etc/debian_version
11.4

for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done

sudo apt-get update
sudo apt-get install ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo apt -y install net-tools openvswitch-switch
ovs-vsctl show

systemctl start docker
systemctl status docker

ovs-vsctl add-br ovs-br0
ovs-vsctl add-br ovs-br1
ovs-vsctl show


#######################-host 1 & 2-#######################
ovs-vsctl add-port ovs-br0 veth0 -- set interface veth0 type=internal
ovs-vsctl add-port ovs-br1 veth1 -- set interface veth1 type=internal

ovs-vsctl show

ip address add 192.168.1.1/24 dev veth0
ip address add 192.168.2.1/24 dev veth1

ip a
ip link set dev veth0 up mtu 1450
ip link set dev veth1 up mtu 1450
ip a


#######################-host 1 & 2-#######################
nano /root/Dockerfile
    FROM ubuntu
    RUN apt update
    RUN apt install -y net-tools
    RUN apt install -y iproute2
    RUN apt install -y iputils-ping
    CMD ["sleep", "7200"]

cd /root/
systemctl start docker.service
docker build . -t ubuntu-docker


#######################-host 1-#######################
docker run -d --net=none --name docker1 ubuntu-docker
docker run -d --net=none --name docker2 ubuntu-docker

docker ps
docker exec docker1 ip a
docker exec docker2 ip a


#######################-host 2-#######################
docker run -d --net=none --name docker3 ubuntu-docker
docker run -d --net=none --name docker4 ubuntu-docker

docker ps
docker exec docker3 ip a
docker exec docker4 ip a


#######################-host 1-#######################
ovs-docker add-port ovs-br0 eth0 docker1 --ipaddress=192.168.1.11/24 --gateway=192.168.1.1
docker exec docker1 ip a

ovs-docker add-port ovs-br1 eth0 docker2 --ipaddress=192.168.2.11/24 --gateway=192.168.2.1
docker exec docker2 ip a

docker exec docker1 ping 192.168.1.1
docker exec docker2 ping 192.168.2.1


#######################-host 2-#######################
ovs-docker add-port ovs-br0 eth0 docker3 --ipaddress=192.168.1.12/24 --gateway=192.168.1.1
docker exec docker3 ip a

ovs-docker add-port ovs-br1 eth0 docker4 --ipaddress=192.168.2.12/24 --gateway=192.168.2.1
docker exec docker4 ip a

docker exec docker3 ping 192.168.1.1
docker exec docker4 ping 192.168.2.1


#######################-host 1-#######################
netstat -ntulp | grep 4789

ovs-vsctl add-port ovs-br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.0.109 options:key=1000
ovs-vsctl add-port ovs-br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=192.168.0.109 options:key=2000

netstat -ntulp | grep 4789
ovs-vsctl show
ip a


#######################-host 2-#######################
netstat -ntulp | grep 4789

ovs-vsctl add-port ovs-br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.0.108 options:key=1000
ovs-vsctl add-port ovs-br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=192.168.0.108 options:key=2000

netstat -ntulp | grep 4789
ovs-vsctl show
ip a


#######################-host 1-#######################
#from docker1, get ping
docker exec docker1 ping 192.168.1.12
docker exec docker1 ping 192.168.1.11
#failed
docker exec docker1 ping 192.168.2.11
docker exec docker1 ping 192.168.2.12

#from docker2, get ping 
docker exec docker2 ping 192.168.2.12
docker exec docker2 ping 192.168.2.11
#failed
docker exec docker2 ping 192.168.1.11
docker exec docker2 ping 192.168.1.12


#######################-host 2-#######################
#from docker3, get ping
docker exec docker3 ping 192.168.1.11
docker exec docker3 ping 192.168.1.12
#failed
docker exec docker3 ping 192.168.2.11
docker exec docker3 ping 192.168.2.12

#from docker4, get ping 
docker exec docker4 ping 192.168.2.11
docker exec docker4 ping 192.168.2.12
#failed
docker exec docker4 ping 192.168.1.11
docker exec docker4 ping 192.168.1.12


#######################-host 1 & 2-#######################
cat /proc/sys/net/ipv4/ip_forward
    1

#if get the value from previous command 1, nothing to do anythings.
#if get value 0, the go for that
sysctl -w net.ipv4.ip_forward=1
sysctl -p /etc/sysctl.conf
cat /proc/sys/net/ipv4/ip_forward

iptables -t nat -L -n -v

iptables --append FORWARD --in-interface veth0 --jump ACCEPT
iptables --append FORWARD --out-interface veth0 --jump ACCEPT
iptables --table nat --append POSTROUTING --source 192.168.1.0/24 --jump MASQUERADE

iptables --append FORWARD --in-interface veth1 --jump ACCEPT
iptables --append FORWARD --out-interface veth1 --jump ACCEPT
iptables --table nat --append POSTROUTING --source 192.168.2.0/24 --jump MASQUERADE

ping 8.8.8.8 -c 2

Congratulations!

