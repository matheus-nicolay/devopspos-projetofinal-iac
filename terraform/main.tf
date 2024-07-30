resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "student-rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Cria rede vritual
resource "azurerm_virtual_network" "student-vnet" {
  name                = "student-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.student-rg.location
  resource_group_name = azurerm_resource_group.student-rg.name

  depends_on = [azurerm_resource_group.student-rg]
}

# Cria subnet
resource "azurerm_subnet" "student-subnet" {
  name                 = "student-subnet"
  resource_group_name  = azurerm_resource_group.student-rg.name
  virtual_network_name = azurerm_virtual_network.student-vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  depends_on = [azurerm_virtual_network.student-vnet, azurerm_resource_group.student-rg]
}

resource "azurerm_network_security_group" "student-subnetsg" {
  #checkov:skip=CKV_AZURE_10:Necessário para aplicar o Ansible a partir da pipeline
  name                = "student-subnetsg"
  location            = azurerm_resource_group.student-rg.location
  resource_group_name = azurerm_resource_group.student-rg.name

  security_rule {
    name                       = "AllowOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.student-rg]
}

resource "azurerm_subnet_network_security_group_association" "student-subnetassociation" {
  subnet_id                 = azurerm_subnet.student-subnet.id
  network_security_group_id = azurerm_network_security_group.student-subnetsg.id

  depends_on = [azurerm_subnet.student-subnet, azurerm_network_security_group.student-subnetsg]
}

# Cria IP publicos
resource "azurerm_public_ip" "student-pip" {
  name                = "student-pip"
  location            = azurerm_resource_group.student-rg.location
  resource_group_name = azurerm_resource_group.student-rg.name
  allocation_method   = "Dynamic"

  depends_on = [azurerm_resource_group.student-rg]
}

# Cria SG e regras
resource "azurerm_network_security_group" "student-nsg" {
  #checkov:skip=CKV_AZURE_10:Necessário para aplicar o Ansible a partir da pipeline
  name                = "student-nsg"
  location            = azurerm_resource_group.student-rg.location
  resource_group_name = azurerm_resource_group.student-rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  depends_on = [azurerm_resource_group.student-rg]
}

# Cria NIC
resource "azurerm_network_interface" "student-nic" {
  #checkov:skip=CKV_AZURE_119:É necessário possuir IP público para acesso SSH do Ansible
  name                = "student-nic"
  location            = azurerm_resource_group.student-rg.location
  resource_group_name = azurerm_resource_group.student-rg.name

  ip_configuration {
    name                          = "nic_configuration"
    subnet_id                     = azurerm_subnet.student-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.student-pip.id
  }

  depends_on = [azurerm_resource_group.student-rg, azurerm_subnet.student-subnet, azurerm_public_ip.student-pip]
}

# Conecta SG com nic
resource "azurerm_network_interface_security_group_association" "nicNSG" {
  network_interface_id      = azurerm_network_interface.student-nic.id
  network_security_group_id = azurerm_network_security_group.student-nsg.id

  depends_on = [azurerm_network_interface.student-nic, azurerm_network_security_group.student-nsg]
}

# Cria a maquina virtual
resource "azurerm_linux_virtual_machine" "student-vm" {
  #checkov:skip=CKV_AZURE_178:Foi escolhido usuário e senha como forma de autenticação nesse projeto
  #checkov:skip=CKV_AZURE_149:Foi escolhido usuário e senha como forma de autenticação nesse projeto
  #checkov:skip=CKV_AZURE_1:Foi escolhido usuário e senha como forma de autenticação nesse projeto
  name                            = "student-vm"
  location                        = azurerm_resource_group.student-rg.location
  resource_group_name             = azurerm_resource_group.student-rg.name
  network_interface_ids           = [azurerm_network_interface.student-nic.id]
  size                            = "Standard_B1s"
  allow_extension_operations      = false
  provision_vm_agent              = true
  disable_password_authentication = false

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "student-vm"
  admin_username = var.username

  admin_password = var.vm_admin_password

  depends_on = [azurerm_resource_group.student-rg, azurerm_network_interface.student-nic]
}

resource "local_file" "ansible_inventory" {
  content  = <<EOF
[all]
${azurerm_linux_virtual_machine.student-vm.name} ansible_host=${azurerm_linux_virtual_machine.student-vm.public_ip_address} ansible_user=${var.username} ansible_password=${var.vm_admin_password}
EOF
  filename = "../ansible/inventory.ini"

  depends_on = [azurerm_linux_virtual_machine.student-vm]
}
