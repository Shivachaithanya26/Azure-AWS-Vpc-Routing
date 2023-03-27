Multi-Cloud with Azure and AWS — Site-to-site VPN

![image](https://user-images.githubusercontent.com/114140254/227914921-d271b612-9f46-452d-96a6-bf7f6f3abd1e.png)

Introduction

This is what we are aiming at:

![image](https://user-images.githubusercontent.com/114140254/227915891-2daa9f41-b8ee-4de1-ad07-9416e8d00afb.png)

Initialize Azure

Let’s start building the Azure resources. When using Terraform, the best practice is to create an Azure Service Principal. I’m using Azure CLI to create the service principal and a resource group. At the time writing this, I’m using Azure cli version 2.0.45

Login to Azure using the CLI.

az login

Complete the login in the browser and cli will display the list of subscriptions.

[
  {
  
    "cloudName": "AzureCloud",
    "id": "[SUBSCRIPTION_ID]",
    "isDefault": false,
    "name": "Your subs name",
    "state": "Enabled",
    "tenantId": "[TENANT_ID]",
    "user": {
      "name": "user@domain.com",
      "type": "user"
  
  } 
  }
]

Select the subscription you want to use and create a new service principal. az ad sp create-for-rbac command creates a service principal and configures access to Azure resources. Service principal name is set to terraform multi

az account set --subscription="[SUBSCRIPTION_ID]"

az ad sp create-for-rbac --role="Contributor" --name="terraformmulti" --scopes="/subscriptions/[SUBSCRIPTION_ID]"

Creating a service principal return a json response with client id (appId) and client secret (password). Copy the response, this will be the last time password is displayed.

{

  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "terraformmulti",
  "name": "http://terraformmulti",
  "password": "00000000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"

}

I created the resource group with Azure CLI. Resource group could be created with Terraform as well. In some cases the service principal you are using has limited contributor privileges and creating a new resource group is restricted.

az group create --name "multirg" --location "westeurope"

Initialize AWS

For the AWS setup I was a bit lazier. I had a user created earlier and just decided to use that. Terraform supports multiple authentication methods and I used the simplest one with aws_access_key and aws_secret_key. I will describe the usage a bit later. The user belongs to the Administrators group so it has all the rights imaginable.

Terraform part 1

Terraform is an open-source infrastructure as code software tool created by HashiCorp. It enables users to define and provision a datacenter infrastructure using a high-level configuration language known as Hashicorp Configuration Language, or optionally JSON. — Wikipedia

Well said, In my terraform scripts I decided to use the Hashicorp Configuration Language (HCL) to create the infra as code. It’s quite intuitive YAML like configuration language. Compared to Azure Resource Manager Templates (ARM) or Cloud Formation templates I find it much clearer. Terraform is a single binary so installation is most simple on all operating systems.

Let’s start creating the resources. I will use a variable file that contains all of my secrets which can be used quite easily in local environment and also in CI/CD tools like Azure DevOps. More about the CI/CD variables later…

For configuration I’m using VS Code with Terraform extension. I have 3 files, aws-vpc.tf, azure-vnet.tf and terraform.tfvars. You can have as many files you want or just a single file, terraform does a pretty good job on finding even the depencies on the resources.
Variables

To persist variable values, I create file called terraform.tfvars. Terraform uses this file to load the populate variables used in the actual terraform configuration files. Variables can be populated from environment variables as well, check that and other possibilities from Terraform documentation which is quite extensive…
{

aws_access_key = "[MYACCESSKEY]"
aws_secret_key = "[MYSECRETKEY]"
azure_client_id= "00000000-0000-0000-0000-000000000000"
azure_client_secret="00000000-0000-0000-0000-000000000000"
tenant_id="00000000-0000-0000-0000-000000000000"

}
Initialize the variables and AWS Provider

To intialize the AWS provider I’m using the persisted variable from tfvars file. Now this is in the Hashicorp Configuration Language (HCL), it’s quite readable, right?

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "region" {
    default = "eu-west-1"
}
provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    version = "~> 2.0"
    region  = "${var.region}"
}

Create Virtual Networks

Lets start by creating the virtual network in AWS. When adding new resources we eventually reach to a point where this network is joined with Azure virtual network with two VPN tunnels.

First we create the AWS Virtual Private Cloud resource. Sounds difficult, but see, three lines of code! How awesome!

resource "aws_vpc" "vpc1" {
    cidr_block = "192.168.0.0/16"
    tags = {
        Name = "Default VPC"
    }
}

Add a subnet, notice the reference to the vpc_id. The resource block created earlier a resource of the given TYPE (first parameter = aws_vpc) and NAME (second parameter = vpc1). Therefore we can reference to the created resource with a syntax ${type.name.attribute}. There is also variety of functions like the one used here cidrsubnet(prefix, newbits, netnum) which calculates a subnet address within given IP network address prefix.

resource "aws_subnet" "main" {
  vpc_id            = "${aws_vpc.vpc1.id}"
  cidr_block        = "${cidrsubnet(aws_vpc.vpc1.cidr_block, 4, 1)}"
  tags = {
    Name = "main"
  }
}

Testing

Now it’s probably also a good time to test the code. You can checkout the code from my github repository or create your own:

git clone https://github.com/jiivari/Multicloud.git
git checkout FirstPhase

Open folder “terraform” with your console. Terraform needs to be initialized to load the required providers. In the first phase we only have the AWS provider in us.

terraform init

Modify the terraform.tfvars file with your AWS and Azure secrets. Let’s execute terraform plan to see the resource creation plan.

terraform planOutput:
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.
------------------------------------------------------------------------
An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create
Terraform will perform the following actions:
  + aws_subnet.main
      id:                               <computed>
      arn:                              <computed>
      assign_ipv6_address_on_creation:  "false"
      availability_zone:                <computed>
      availability_zone_id:             <computed>
      cidr_block:                       "10.0.16.0/20"
      ipv6_cidr_block:                  <computed>
      ipv6_cidr_block_association_id:   <computed>
      map_public_ip_on_launch:          "false"
      owner_id:                         <computed>
      tags.%:                           "1"
      tags.Name:                        "main"
      vpc_id:                           "${aws_vpc.vpc2.id}"
  + aws_vpc.vpc2
      id:                               <computed>
      arn:                              <computed>
      assign_generated_ipv6_cidr_block: "false"
      cidr_block:                       "10.0.0.0/16"
      default_network_acl_id:           <computed>
      default_route_table_id:           <computed>
      default_security_group_id:        <computed>
      dhcp_options_id:                  <computed>
      enable_classiclink:               <computed>
      enable_classiclink_dns_support:   <computed>
      enable_dns_hostnames:             <computed>
      enable_dns_support:               "true"
      instance_tenancy:                 "default"
      ipv6_association_id:              <computed>
      ipv6_cidr_block:                  <computed>
      main_route_table_id:              <computed>
      owner_id:                         <computed>
      tags.%:                           "1"
      tags.Name:                        "New VPC"
Plan: 2 to add, 0 to change, 0 to destroy.
------------------------------------------------------------------------
Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.

If I now apply the changes I will get two new resources. Note that Terraform has support for backends, which is a way of storing the current state. The default backend is local, which means the state will be saved in the Terraform working directory, in a file called terraform.tfstate. You can store the state in Azure Blob Storage or AWS S3 bucket as well.

Next command is to apply the code.

terraform apply

Executing the code is pretty fast, takes only seconds to complete. Now you have a virtual private cloud with one subnet in AWS. After a successful test we will clear the resources which is amazing in terraform. We just simply need to call the destroy command.

terraform destroy

Terraform part 2

Let’s continue to create more resources. Now we create the resources into Azure. Before creating resources in Azure we need to initialize the Azure provider.
Initialize the variables and Azure Provider

If you didn’t do it already, modify the tfvars file with the service principals client_id, client_secret and tenant_id. Azure location is set as default in the location variable, it could be added to tfvars as well. Defaults can be overwritten by setting the parameter in variables file or in environment variable.

variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "tenant_id" {}variable "location" {
  default = "West Europe"
}provider "azure" {
    client_id = "${var.azure_client_id}"
    client_secret = "${var.azure_client_secret}"
    tenant_id = "${var.tenant_id}"
}

Virtual Network

Next simple task it to create virtual network called “vnet1” to resource group “multirg”. Resource group was created earlier with the Azure CLI.

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet1"
  location            = "${var.location}"
  resource_group_name = "multirg"
  address_space       = ["172.16.0.0/16"]
}

Add subnets, one for Azure Virtual Network Gateway and one that is connected to AWS VPC.

resource "azurerm_subnet" "subnet" {
  name                 = "subnet1"
  resource_group_name  = "multirg"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "172.16.1.0/24"
}
resource "azurerm_subnet" "GatewaySubnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = "multirg"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  address_prefix       = "172.16.2.0/28"
}

Gateways

Add a Virtual Network Gateway and a public IP Address for it. Notice that we haven’t used any depends_on parameters yet. Even if the configurations are in different physical files Terraform is able to find the dependencies automatically.

resource "azurerm_public_ip" "gwpip" {
  name                    = "vnetvgwpip1"
  location                = "${var.location}"
  resource_group_name     = "multirg"
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30
}resource "azurerm_virtual_network_gateway" "vng" {
  name                = "myvng1"
  location            = "${var.location}"
  resource_group_name = "multirg"  type     = "Vpn"
  vpn_type = "RouteBased"
  
  active_active = falseenable_bgp    = false
  sku           = "VpnGw1"
  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = "${azurerm_public_ip.gwpip.id}"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = "${azurerm_subnet.GatewaySubnet.id}"
  }
}

Now the interesting part. We will create an AWS customer gateway. This is now depending on the Azure public IP address created for Azure virtual network gateway. The depends_on parameter is set to explicitly define the dependency. Most probably it wasn’t even required.

resource "aws_customer_gateway" "main" {
  bgp_asn    = 65000
  ip_address = "${azurerm_public_ip.gwpip.ip_address}"type       = "ipsec.1"
  tags = {
    Name = "main-customer-gateway"
  }
  depends_on = ["azurerm_public_ip.gwpip"]
}

Next is the AWS virtual private gateway and a vpn connection connecting the two gateways. We need to use static routes only and create a route between the Azure subnet and AWS gateway.

resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = "${aws_vpc.vpc1.id}"
  tags = {
    Name = "main"
  }
}resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = "${aws_vpn_gateway.vpn_gw.id}"
  customer_gateway_id = "${aws_customer_gateway.main.id}"type                = "ipsec.1"
  static_routes_only  = true
}resource "aws_vpn_connection_route" "azure" {
  destination_cidr_block = "${azurerm_subnet.subnet.address_prefix}"
  vpn_connection_id      = "${aws_vpn_connection.main.id}"
}

AWS vpn connection creates two tunnels by default for automatic failover. To connect these tunnels we create two Azure local network gateways. Gateway addresses comes from AWS vpn tunnel “tunnel1_address” and “tunnel2_address” and the address space is the VPC1 cidr_block for both tunnels.

resource "azurerm_local_network_gateway" "lngw1" {
  name                = "azlngw1"
  resource_group_name = "multirg"
  location            = "${var.location}"
  gateway_address     = "${aws_vpn_connection.main.tunnel2_address}"
  address_space       = ["${aws_vpc.vpc1.cidr_block}"]
}
resource "azurerm_local_network_gateway" "lngw2" {
  name                = "azlngw2"
  resource_group_name = "multirg"
  location            = "${var.location}"
  gateway_address     = "${aws_vpn_connection.main.tunnel1_address}"
  address_space       = ["${aws_vpc.vpc1.cidr_block}"]
}

Both local network gateways are then connected to the Azure virtual network gateway and AWS vpn. Connection is authenticated using the preshared key created by the AWS vpn.

resource "azurerm_virtual_network_gateway_connection" "vngc1" {
  name                = "vngc1"
  location            = "${var.location}"
  resource_group_name = "multirg"
  type                       = "IPsec"
  virtual_network_gateway_id = "${azurerm_virtual_network_gateway.vng.id}"
  local_network_gateway_id   = "${azurerm_local_network_gateway.lngw1.id}"
  shared_key = "${aws_vpn_connection.main.tunnel2_preshared_key}"
}
resource "azurerm_virtual_network_gateway_connection" "vngc2" {
  name                = "vngc2"
  location            = "${var.location}"
  resource_group_name = "multirg"
  type                       = "IPsec"
  virtual_network_gateway_id = "${azurerm_virtual_network_gateway.vng.id}"
  local_network_gateway_id   = "${azurerm_local_network_gateway.lngw2.id}"
  shared_key = "${aws_vpn_connection.main.tunnel1_preshared_key}"
}

Routing

Last but not least create the routing tables. The routing tables forward the network traffic in AWS cidr block range in Azure to virtual network gateway and Azure subnet cidr block range in AWS to vpn gateway.

resource "aws_route" "azureroute" {
  route_table_id            = "${aws_vpc.vpc1.main_route_table_id}"
  destination_cidr_block    = "${azurerm_subnet.subnet.address_prefix}"
  gateway_id                = "${aws_vpn_gateway.vpn_gw.id}"
}resource "azurerm_route_table" "route" {
  name                          = "awsroute"
  location                      = "${var.location}"
  resource_group_name           = "multirg"
  route {
    name           = "awsroute"
    address_prefix = "${aws_vpc.vpc1.cidr_block}"
    next_hop_type  = "VirtualNetworkGateway"
  }}

The Code

Get the complete code from my github repository Multicloud, branch Complete. Remember to initialize the terraform again if executing azure provider resources for the first time

git clone https://github.com/jiivari/Multicloud.git
git checkout Complete

As a result both tunnels should be up
Troubleshooting

If the tunnels are down for some reason, it’s probably because of the Azure local network gateway and virtual network gateway connection parameters. As you might saw, there is some weird issue about “tunnel1_address” and “tunnel1_preshared_key”. For some reason it seems to be mixed on the response. In my configuration lngw1 has tunnel2_address but the vngc1 has tunnel2_preshared_key.
Conclusion

That’s it, you should have the VPN connection between Azure and AWS. Now let’s test the tunnel by setting up some easy resources. The easiest way is to create virtual machines in both environments and use ping. You can do this easily with terraform as well but I did it in the good old fashion; manually in portal. Remember to add Internet Gateway and routing to AWS to enable shh into EC2…

Ping from Azure VM to AWS EC2 instance with private IP Address.

And ping the other way around, from EC2 to Azure VM
