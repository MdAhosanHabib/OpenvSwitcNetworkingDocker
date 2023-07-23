<img width="601" alt="VXLAN OPENVSWITCH DOCKER" src="https://github.com/MdAhosanHabib/OpenvSwitcNetworkingDocker/assets/43145662/a01ce9e3-e4e9-4ce6-b82e-84e2aef4db9e">

# OpenvSwitch Networking with Docker on Debian Hosts

## Introduction
This project demonstrates how to set up a network using OpenvSwitch and Docker on Debian hosts. The network consists of two hosts, each running Docker containers connected through OpenvSwitch bridges. This setup allows for isolated container communication across multiple hosts using virtual extensible LANs (VXLANs).


## Technologies Used

- Debian 11.4: The Debian operating system version used as the base for the hosts.

- Docker: A containerization platform that allows running applications in isolated environments called containers.

- OpenvSwitch: A virtual switch that provides network virtualization capabilities and is used to create bridges for Docker containers.


## Installation and Setup

- (host 1 & 2)Install required packages, including Docker and OpenvSwitch, on Debian hosts:
```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl start docker
systemctl status docker

sudo apt -y install net-tools openvswitch-switch
ovs-vsctl show
```

- (host 1 & 2)Create OpenvSwitch bridges on each host to facilitate communication between Docker containers:
```bash
ovs-vsctl add-br ovs-br0
ovs-vsctl add-br ovs-br1
ovs-vsctl show
```

- (host 1 & 2)Set up two internal interfaces, veth0 and veth1, and assign IP addresses:
```bash
ovs-vsctl add-port ovs-br0 veth0 -- set interface veth0 type=internal
ovs-vsctl add-port ovs-br1 veth1 -- set interface veth1 type=internal

ovs-vsctl show

ip address add 192.168.1.1/24 dev veth0
ip address add 192.168.2.1/24 dev veth1

ip a
ip link set dev veth0 up mtu 1450
ip link set dev veth1 up mtu 1450
ip a
```

- (host 1 & 2)Build a custom Docker image that includes the necessary networking tools:
```bash
nano /root/Dockerfile
  FROM ubuntu
  RUN apt update
  RUN apt install -y net-tools
  RUN apt install -y iproute2
  RUN apt install -y iputils-ping
  CMD ["sleep", "7200"]
```
```bash
cd /root/
systemctl start docker.service
docker build . -t ubuntu-docker
```

## Container Deployment

- (host 1)Run Docker containers with no network attachment:
```bash
docker run -d --net=none --name docker1 ubuntu-docker
docker run -d --net=none --name docker2 ubuntu-docker

docker ps
docker exec docker1 ip a
docker exec docker2 ip a
```
- (host 2)Run Docker containers with no network attachment:
```bash
docker run -d --net=none --name docker3 ubuntu-docker
docker run -d --net=none --name docker4 ubuntu-docker

docker ps
docker exec docker3 ip a
docker exec docker4 ip a
```

- (host 1)Attach Docker containers to the OpenvSwitch bridges and configure IP addresses and gateways:
```bash
ovs-docker add-port ovs-br0 eth0 docker1 --ipaddress=192.168.1.11/24 --gateway=192.168.1.1
docker exec docker1 ip a

ovs-docker add-port ovs-br1 eth0 docker2 --ipaddress=192.168.2.11/24 --gateway=192.168.2.1
docker exec docker2 ip a

docker exec docker1 ping 192.168.1.1
docker exec docker2 ping 192.168.2.1
```
- (host 2)Attach Docker containers to the OpenvSwitch bridges and configure IP addresses and gateways:
```bash
ovs-docker add-port ovs-br0 eth0 docker3 --ipaddress=192.168.1.12/24 --gateway=192.168.1.1
docker exec docker3 ip a

ovs-docker add-port ovs-br1 eth0 docker4 --ipaddress=192.168.2.12/24 --gateway=192.168.2.1
docker exec docker4 ip a

docker exec docker3 ping 192.168.1.1
docker exec docker4 ping 192.168.2.1
```

## VXLAN Configuration

- (host 1)Add VXLAN ports to the OpenvSwitch bridges for container communication across hosts:
```bash
netstat -ntulp | grep 4789

ovs-vsctl add-port ovs-br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.0.109 options:key=1000
ovs-vsctl add-port ovs-br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=192.168.0.109 options:key=2000

netstat -ntulp | grep 4789
ovs-vsctl show
ip a
```
- (host 2)Add VXLAN ports to the OpenvSwitch bridges for container communication across hosts:
```bash
netstat -ntulp | grep 4789

ovs-vsctl add-port ovs-br0 vxlan0 -- set interface vxlan0 type=vxlan options:remote_ip=192.168.0.108 options:key=1000
ovs-vsctl add-port ovs-br1 vxlan1 -- set interface vxlan1 type=vxlan options:remote_ip=192.168.0.108 options:key=2000

netstat -ntulp | grep 4789
ovs-vsctl show
ip a
```

- (host 1)Verify network connectivity between Docker containers running on different hosts:
```bash
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
```
- (host 2)Verify network connectivity between Docker containers running on different hosts:
```bash
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
```


## IP Forwarding and NAT

- (host 1 & 2)Ensure that IP forwarding is enabled on both hosts:
```bash
cat /proc/sys/net/ipv4/ip_forward
# Check if the value is 1, which means IP forwarding is already enabled.

# If IP forwarding is not enabled (value is 0), run the following command:
sysctl -w net.ipv4.ip_forward=1
sysctl -p /etc/sysctl.conf
```

- (host 1 & 2)Enable NAT for container communication outside of the host network:
```bash
iptables -t nat -L -n -v

iptables --append FORWARD --in-interface veth0 --jump ACCEPT
iptables --append FORWARD --out-interface veth0 --jump ACCEPT
iptables --table nat --append POSTROUTING --source 192.168.1.0/24 --jump MASQUERADE

iptables --append FORWARD --in-interface veth1 --jump ACCEPT
iptables --append FORWARD --out-interface veth1 --jump ACCEPT
iptables --table nat --append POSTROUTING --source 192.168.2.0/24 --jump MASQUERADE

ping 8.8.8.8 -c 2
```

Now the network setup is complete, and containers on different hosts should be able to communicate with each other. You can test the connectivity by running ping commands between containers on different hosts.

Congratulations! Your OpenvSwitch network with Docker on Debian hosts is up and running.
