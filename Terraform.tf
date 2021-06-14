#########################################Defining Provider
provider "azurerm" {
  
  features {}
}

#########################################Varibles
variable "RG_Name" {
  type = string
}

variable "Vnet_Name" {
  type = string
}
variable "Vnet_addressspace" {
  type = list
}

variable "Timezone" {
  type = string
}

variable "server_list" {
	type = list
}

variable "VM_username" {
  type = string
}
variable "storageaccountname" {
  type = string
}
############################################Defining varibles
RG_Name = "MacroLife_RG"
Vnet_Name = "MacroLife-vnet"
Vnet_addressspace = ["10.0.0.0/16"]
Timezone = "Pacific Standard Time"

storageaccountname = "macrolifestorageacc"

#####Key vault details are hardcoded in Terraform.tf file

VM_username = "Azureuser"
server_list  = [
    {
        hostname = "server1"
        SKU = "Standard_DS1_v2"
		osDiskType = "StandardSSD_LRS"
		Subnet = ["10.0.1.0/24"]
    } ,
    {
        hostname = "server2"
        SKU = "Standard_DS1_v2"
		osDiskType = "StandardSSD_LRS"
		Subnet = ["10.0.2.0/24"]
    }
]
##########################################Pulling Password from Key Vault

data "azurerm_key_vault" "keyvault" {
  name                = "MacroLife-keyvault"
  resource_group_name = "Terraform_res"
}

data "azurerm_key_vault_secret" "secret" {
  name         = "VMPASSWORD"
  key_vault_id = data.azurerm_key_vault.keyvault.id
}

#########################################Creating Resource Group
resource "azurerm_resource_group" "RGName" {
  name     = var.RG_Name
  location = "eastus2"
}

##########################################Creating Vnet and Subnets
resource "azurerm_virtual_network" "vnet" {
  name                = var.Vnet_Name
  location            = azurerm_resource_group.RGName.location
  resource_group_name = azurerm_resource_group.RGName.name
  address_space       = var.Vnet_addressspace
}
 
################Creating subnet
resource "azurerm_subnet" "subnets" {
  name                 = "Subnet-${count.index + 1}"
  resource_group_name  = azurerm_resource_group.RGName.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes       = lookup(var.server_list[count.index], "Subnet")
  service_endpoints = ["Microsoft.Storage"]
  count = length(var.server_list)
}

########################################## Creating NSG

resource "azurerm_network_security_group" "NSGs" {
  name                = "${lookup(var.server_list[count.index], "hostname")}-NSG"
  location            = azurerm_resource_group.RGName.location
  resource_group_name = azurerm_resource_group.RGName.name
  count = length(var.server_list)
  
    security_rule {
    name                       = "Allow-Inbound-HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
	}
    security_rule {
    name                       = "Allow-Inbound-HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
	}
    security_rule {
    name                       = "Allow-Outbound-HTTPS"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
	}
    security_rule {
    name                       = "Allow-Outbound-HTTP"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
	}
  
}
########################################## Creating NIcs
resource "azurerm_network_interface" "nic" {
  name                = "${lookup(var.server_list[count.index], "hostname")}-NIC"
  location            = azurerm_resource_group.RGName.location
  resource_group_name = azurerm_resource_group.RGName.name
  count				  = length(var.server_list)
  ip_configuration {
    name                          = "${lookup(var.server_list[count.index], "hostname")}-IP"
    subnet_id                     = element(azurerm_subnet.subnets.*.id, count.index)
    private_ip_address_allocation = "Dynamic"
    
  }
}


resource "azurerm_network_interface_security_group_association" "association" {
  network_interface_id      = element(azurerm_network_interface.nic.*.id, count.index)
  network_security_group_id = element(azurerm_network_security_group.NSGs.*.id, count.index)
  count				  = length(var.server_list)
}

########################################## Creating VMs

resource "azurerm_windows_virtual_machine" "vm" {
  name= lookup(var.server_list[count.index], "hostname")
  resource_group_name= azurerm_resource_group.RGName.name
  location= azurerm_resource_group.RGName.location
  size= lookup(var.server_list[count.index], "SKU")
  license_type = "Windows_Server"
  count = length(var.server_list)
  admin_username      = var.VM_username
  admin_password      = data.azurerm_key_vault_secret.secret.value
  network_interface_ids = [element(azurerm_network_interface.nic.*.id, count.index)]

  os_disk {
    name                = "${lookup(var.server_list[count.index], "hostname")}-OS-Disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

########################################## StorageAccount

resource "azurerm_storage_account" "StorageAccount" {
  name                     = var.storageaccountname
  resource_group_name      = azurerm_resource_group.RGName.name
  location                 = azurerm_resource_group.RGName.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

}

