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