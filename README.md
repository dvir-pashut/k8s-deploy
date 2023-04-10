# k8s-deploy


### "k8s-deploy" is a repository that contains 2 scripts that will deploy k8s on your machine(s) just make sure to use the correct script for your machine.


## Requirements

2 GB or more of RAM per machine (any less will leave little room for your apps).
2 CPUs or more.

## Usage

```sh
Usage: <script> [-m] [-h]
  -m    For Master node
  -h    Show usage
```

## information

this script installing k8s using [kubeadm]. and installing flannel [CNI] (Container Network Interface).

you can also use this a a startup script for worker nodes



## Contributing

Pull requests are welcome. For major changes, please open an issue first
to discuss what you would like to change.

## License

no license!!!!!!!!!!!

free software

[//]: # 

[kubeadm]: <https://kubernetes.io/docs/reference/setup-tools/kubeadm/>
[CNI]: <https://github.com/containernetworking/cni>