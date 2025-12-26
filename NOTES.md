# angelnu NOTES

## Preparation

1. Download `pxe` ISO
   1. download the iPXE bootloader as ISO
   2. update [pxe_iso_os](vars/main.yaml)
2. Create `centos10-cloudinit` VM
   1. create empty VM without any disk
   2. into Proxmox with the VM: wget qcow2 from https://cloud.centos.org/centos/10-stream/x86_64/images/
   3. detach and delete disk in existing template (if you are updating the template)
   4. `qm importdisk <VM id> centos.qcow2 local-lvm`
   5. `qm set <VM id> --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-<VM id>-disk-0 
   6. make the VM a template
3. Create secrets.auto.tfvars

   ```ini
   api_url                = "https://pve1.angelnu.com:8006/api2/json"
   user                   = "root@pam"
   passwd                 = "Proxmox password"
   ansible_pwd            = "password for ansible user at service VM"
   ansible_ssh_public_key = "public key to ssh into service VM"
   ```

4. Adjust other settings into the [vars folder](vars)
5. Create following DNS records:

   ```yaml
   - type: A
     name: okd-service.homelab
     value: 192.168.251.196
   - type: CNAME
     name: '*.okd.homelab'
     value: okd-service.homelab
   - type: CNAME
     name: '*.apps.okd.homelab'
     value: okd-service.homelab
   ```

## How to install

1. Create virtual machine

   ```shell
   terraform init
   terraform apply
   ```

2. `ansible-playbook setup-linux.yaml`
3. Start bootstrap VM
4. From Service VM: `openshift-install --dir=install_dir/ wait-for bootstrap-complete --log-level=info`
5. Start master node VMs
6. Once the openshift-install indicated the bootstrap is done then stop boorstrap VM. Note - I did not remove it from the haproxy
7. From Service VM: `openshift-install --dir=install_dir/ wait-for install-complete --log-level=info`
8. Start the worker nodes
9. From the Service VM (use another session in parallel to the openshift-install one):
    1.  `export KUBECONFIG=~/install_dir/auth/kubeconfig`
    2.  Monitor Pending CSRs: `oc get csr | grep Pending`
    3.  Approve pending CSRs: `oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve`
10. Wait for the openshift-install to complete and get the credentials to log into the console
11. Service node has a webb interface at https://192.168.251.196:9090/

## ToDos

1. Automate further:
2. Install flux
3. Open to outside (install cloudflare operator)
4. Check I can install 2 clusters in parallel (one for test)
5. Check how to recover cluster