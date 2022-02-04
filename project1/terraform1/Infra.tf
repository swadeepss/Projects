
# Terraform Block
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.0" 
    }
    random = {
        source = "hashicorp/random"
        version= ">=3.0"
    }
  }
}

# Provider Block
provider "azurerm" {
 features {}          
}


# Resource-1: Azure Resource Group
resource "azurerm_resource_group" "myrg" {
  name = "swatterra-RG"
  location = "East US"
}

#To generate a random values
resource "random_string" "string" {
    length = 16
    special = false
    upper = false

}

# Resource-2: Create Virtual Network
resource "azurerm_virtual_network" "myvnet" {
  name                = "VNetworkmain"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
  tags = {
    "Name" = "VNetworkmain"
    #"Environment" = "Dev"  # Uncomment during Step-10
  }
}


# Resource-3: Create Subnet 1

resource "azurerm_subnet" "Vnet-subnet-web" {
  name                 = "Vnet-subnet-web"
  resource_group_name  = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Resource-3: Create Subnet 2

resource "azurerm_subnet" "Vnet-subnet-Data" {
  name                 = "Vnet-subnet-Data"
  resource_group_name  = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Resource-3: Create Subnet 3

resource "azurerm_subnet" "Vnet-subnet-host" {
  name                 = "Vnet-subnet-host"
  resource_group_name  = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes     = ["103.120.51.232"]
}


# Resource-4: Create Public IP Address
resource "azurerm_public_ip" "mypublicip" {
  name                = "mypublicip-1"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  allocation_method   = "Static"
  tags = {
    environment = "Dev"
  }
}

# Resource-5: Create Network Interface
resource "azurerm_network_interface" "myvmnic" {
  name                = "vmnic"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Vnet-subnet-host.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.mypublicip.id 
  }
}

resource "azurerm_network_security_group" "NSGHost" {
  name                = "NSGHostnsg"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name

  security_rule {
    name                       = "test123"
    priority                   = 22
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "NSGWeb" {
  name                = "NSGWeb"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
}


resource "azurerm_network_security_group" "NSGData" {
  name                = "NSGData"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
}


resource "azurerm_subnet_network_security_group_association" "Vnet-subnet-host" {
  subnet_id                 = azurerm_subnet.Vnet-subnet-host.id
  network_security_group_id = azurerm_network_security_group.NSGHost.id
}


resource "azurerm_subnet_network_security_group_association" "Vnet-subnet-web" {
  subnet_id                 = azurerm_subnet.Vnet-subnet-web.id
  network_security_group_id = azurerm_network_security_group.NSGWeb.id

}


resource "azurerm_subnet_network_security_group_association" "Vnet-subnet-Data" {
  subnet_id                 = azurerm_subnet.Vnet-subnet-Data.id
  network_security_group_id = azurerm_network_security_group.NSGData.id
} 



# Create virtual machine VMHost
resource "azurerm_linux_virtual_machine" "VMHOST" {
    name                  = "VMHost"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myrg.name
    network_interface_ids = [azurerm_subnet.Vnet-subnet-host.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }


    module "run_command" {
        source               = "innovationnorway/vm-run-command/azurerm"
        resource_group_name  = "${azurerm_resource_group.myrg.name}"
        virtual_machine_name = "${azurerm_virtual_machine.myrg.name}"
        os_type              = "linux"

        command = "apt-get install -y curl"
          script = <<EOF
            add-apt-repository -y ppa:git-core/ppa
            apt-get update
            apt-get install -y git
            apt-get install apache2
            sudo /etc/init.d/apache2 start
            EOF
     }

    computer_name  = "myvm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = swadeepkey
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}

# Create virtual machine VMWEb
resource "azurerm_linux_virtual_machine" "VMWeb" {
    name                  = "VMWeb"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myrg.name
    network_interface_ids = [azurerm_subnet.Vnet-subnet-web.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    admin_ssh_key {
        username       = "azureuser"
        public_key     = swadeepkey1
    }
}

# Create virtual machine VMHWeb2
resource "azurerm_linux_virtual_machine" "VMWeb2" {
    name                  = "VMWeb2"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myrg.name
    network_interface_ids = [azurerm_subnet.Vnet-subnet-web.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    admin_ssh_key {
        username       = "azureuser"
        public_key     = swadeepkey2
    }

   
}

# Create virtual machine VMData1
resource "azurerm_linux_virtual_machine" "VMData1" {
    name                  = "VMData1"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myrg.name
    network_interface_ids = [azurerm_subnet.Vnet-subnet-Data.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    admin_ssh_key {
        username       = "azureuser"
        public_key     = swadeepkey3
    }

   
}

# Create virtual machine VMData2
resource "azurerm_linux_virtual_machine" "VMData2" {
    name                  = "VMData2"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myrg.name
    network_interface_ids = [azurerm_subnet.Vnet-subnet-Data.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }
    admin_ssh_key {
        username       = "azureuser"
        public_key     = swadeepkey5
    }   

   
}
