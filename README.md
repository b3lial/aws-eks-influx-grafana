# aws-eks-influx-grafana
Run InfluxDB and Grafana in an AWS Kubernetes cluster in a private subnet. Uses cloudformation
to automatically create the infrastructure. Create an application loadbalancer
for HTTPS ingress in a public subnet. Mount EBS volumes in the containers for persistency.

## Setup

In this section, we create

* an EKS k8s cluster based on EC2 instances in a VPC
* add an EBS driver to the cluster for persistent storage
* add an application loadbalancer controller to the cluster 

The following sub-sections describe each step in more detail.

### Cluster
This repository contains a cloud formation template which creates an EKS 
kubernetes cluster. It contains:

* a VPC with two public and one private subnet
* an EKS control plane
* one EKS worker node in the private subnet based on a EC2 instance
* the corresponding roles

You can run the script [01-create-eks-stack.sh](setup/01-create-eks-stack.sh) to
create the infrastructure. The cloud formation template is available [here](setup/eks-vpc-roles.yaml).
After stack creation, you can execute:

```bash
aws eks update-kubeconfig --region region-code --name my-cluster
```

to get kube config file and configure your cluster via `kubectl`.

### Elastic Block Storage Driver
When installing the driver for the first time, we have to make sure
it has proper permissions to access the AWS cloud:

* Create a dedicated user: `aws iam create-user --user-name ebs-csi-user`
* Generate access key credentials (make sure not to forget the secret access key): `aws iam create-access-key --user-name ebs-csi-user`
* Attach a managed policy to this user to provide EBS access: `aws iam attach-user-policy --user-name ebs-csi-user --policy-arn arn:aws:iam::aws:policy/service-role AmazonEBSCSIDriverPolicy`

Finally, we create a kubernetes secret which will be used by the EBS driver:

```bash
kubectl create secret generic aws-secret \
    --namespace kube-system \
    --from-literal "key_id=${USER_ACCESS_KEY_ID}" \
    --from-literal "access_key=${USER_SECRET_ACCESS_KEY}"
```

Afterwards, the driver is installed and verified via:

```bash
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.12"
kubectl get pods -n kube-system
```

A sample application to test your EBS driver can be downloaded [here](https://docs.aws.amazon.com/eks/latest/userguide/ebs-sample-app.html).
More details about the EBS driver are available in its [documentation](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md).

### Application Load Balancer Controller
Unfortunatly, there is no quick and easy way installing a application loadbalancer controller
into a cluster. Therefore, we recommand to stick to the official AWS guides:

* [Application load balancing on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/alb-ingress.html) for a
general introduction and the prerequisites
* [Installing the AWS Load Balancer Controller add-on](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)
to install the controller into the cluster.

In case of problems, read the controllers logs via `kubectl logs -n kube-system deployment.apps/aws-load-balancer-controller`.

## Run Applications

After the cluster is running, we can start the application:

* [Storageclass.yaml](application/storageclass.yaml) and [claim.yaml](application/claim.yaml) create three persistent volume claims
which will be mounted by the pods.
* [Grafana-statefulset.yaml](application/grafana-statefulset.yaml) starts grafana and exposes port 3000 on the node.
* [Influx-statefulset.yaml](application/influx-statefulset.yaml) starts influxdb and exposes port 8086 on the node.
* [Ingress.yaml](application/ingress.yaml) starts an application loadbalancer on HTTPS port 443 and forwards traffic to either
influxdb and grafana depending on the host name. Needs two two domain certificates controlled by AWS. The yaml file has to be modified before usage:
   * Insert two AWS certificates
   * and their domain names into the alb section

## Run Examples

If you just want to play around with the cluster, we also provide a few examples for demonstration purpose:

* [Example-pod.yaml](examples/example-pod.yaml) starts a do-nothing-pod.
* [Nginx-replicatset-class.yaml](examples/nginx-replicaset-classic.yaml) starts nginx and uses AWS classic loadbalancer for ingress listening on HTTP port 80.
* [Nginx-replicatset-alb.yaml](examples/nginx-replicaset-alb.yaml) starts nginx and uses AWS application loadbalancer for ingress listening on HTTP port 80.
* [Nginx-replicatset-alb-https.yaml](examples/nginx-replicaset-alb-https.yaml) starts nginx and uses AWS application loadbalancer for ingress listening on HTTPS port 443.
Do not forget to insert an AWS domain certificate.

