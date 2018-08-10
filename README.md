# Configuration and sample application for SUSE CAP test

Test on SUSE Openstack Cloud
====
 1. Go to folder `ecp`
 2. Follow this [guide](https://github.com/SUSE/cloudfoundry/wiki/Setup-CAP-on-CaaSP-on-ECP) and the [official documentation](https://www.suse.com/documentation/cloud-application-platform-1/book_cap_deployment/data/cha_cap_install-minimal.html)

Test on Amazon EKS (**STILL IN TESTING**)
===
 1. Go to folder `eks`
 2. Run `terraform apply` to create the cluster in AWS
 3. Make sure you have the [latest `kubectl` ready](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
 4. Make sure you have the [`aws-iam-authenticator` binary ready](https://github.com/kubernetes-sigs/aws-iam-authenticator).
 5. Run `terraform output config-map-aws-auth` and save the output to a `<filename>.yml`. NOTE: make sure it's correctly formatted.
 6. Run `kubectl apply -f <filename>.yml` to create a configmap to connect to your EKS cluster.
 7. Have a look at [this guide](https://github.com/SUSE/scf/wiki/Deployment-on-Amazon-EKS).
