#!/bin/bash

show_usage() {
  echo "NOTE: this script is for Ubuntu 22.04 LTS x86/64. (it will not work on Ubuntu 20.04 LTS)"
  echo "Usage: $0 [-m] [-h]"
  echo "  -m    For Master node"
  echo "  -h    Show usage"
}

run_kubeadm=false

while getopts ":hm" opt; do
  case ${opt} in
    m )
      run_kubeadm=true
      ;;
    h )
      show_usage
      exit 0
      ;;
    \? )
      echo "ERROR"
      show_usage
      exit 1
      ;;
    : )
      echo "ERROR: Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

echo "---------------------------Disabling swap-------------------"
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab


echo "--------------------------------installing docker runtime------------------------------"
sudo apt-get update -y

sudo  cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
sudo  cat <<EOF | sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system


sudo apt-get update -y 
yes | sudo apt-get install \
    ca-certificates \
    curl \
    gnupg -y


sudo mkdir -m 0755 -p /etc/apt/keyrings
sudo  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg



echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


sudo apt-get update -y 


sudo apt-get install docker-ce docker-ce-cli containerd.io -y



echo "---------------------------Configure containerd ------------------------"

sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd


echo "---------------------------installing kubeadm-------------------"

sudo apt-get update -y

sudo apt-get install -y apt-transport-https ca-certificates curl 


sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmour -o /etc/apt/trusted.gpg.d/kubernetes-xenial.gpg

yes | sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"



sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl



# Apply sysctl params without reboot
sudo sysctl --system

sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl restart containerd


if [ "$run_kubeadm" = true ]; then
  echo "-------------------  -m detected starting master node preperation---------------"
else
  echo "==============Kubeadm insinstalled.... you can enert conaction link now and then run "sudo systemctl restart kubelet"================"
  exit 0
fi

echo "------------------Setting up hostname----------------------------"
sudo hostnamectl set-hostname "k8s-master"


echo "----------------------------------------starting kubeadm---------------------------------"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16  


sleep 5

echo "------------------giving root and ubuntu the config file-------------------------------"
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

sudo systemctl restart kubelet

echo "-----------------------------waiting for kubelet to start-------------------------"

for i in {1..30}
do
    echo -ne "\r["
    for j in $(seq 1 $i)
    do
        echo -ne "="
    done
    for k in $(seq $i 29)
    do
        echo -ne " "
    done
    echo -ne "] $((i * 100 / 30))%"
    sleep 1
done

echo -ne "\n"

echo  "KUBECONFIG=/home/ubuntu/.kube/config"  >>  ~/.bashrc

echo "-------------------------------installing flannel cni  ---------------------------------- "

source ~/.bashrc


kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.0/manifests/calico.yaml


echo "=====================done===================================="

echo -e  "in case your using solo node cluster make suer to run \n'kubectl taint nodes --all node-role.kubernetes.io/control-plane-' \nso you can deploy pods on the master node"