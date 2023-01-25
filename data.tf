data "azurerm_public_ip" "main_1" {
  name                = azurerm_public_ip.main_1.name
  resource_group_name = azurerm_public_ip.main_1.resource_group_name
  depends_on = [
    azurerm_virtual_network_gateway.main
  ]
}

data "azurerm_public_ip" "main_2" {
  name                = azurerm_public_ip.main_2.name
  resource_group_name = azurerm_public_ip.main_2.resource_group_name
  depends_on = [
    azurerm_virtual_network_gateway.main
  ]
}

resource "aws_vpc" "vpc1" {
    cidr_block = "192.168.0.0/16"
    tags = {
        Name = "Default VPC"
    }
}