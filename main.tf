#####################################################
# VPN Gateway Configuration
# Copyright 2021 IBM
#####################################################

locals {
  name = replace("${var.vpc_name}-${var.label}", "/[^a-zA-Z0-9_\\-\\.]/", "")
  subnet_ids  = var.vpc_subnets[*].id
  output_file = "${path.cwd}/.tmp/vpn-gateways.json"
  output = jsondecode(data.local_file.gateway_output.content)
}

resource null_resource create_gateway {
  count = var.provision ? 1 : 0

  triggers = {
    region = var.region
    resource_group = var.resource_group_id
    subnet_ids = join(",", local.subnet_ids)
    ibmcloud_api_key = var.ibmcloud_api_key
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/create-gateways.sh '${self.triggers.region}' '${self.triggers.resource_group}' '${local.name}' '${self.triggers.subnet_ids}'"

    environment = {
      IBMCLOUD_API_KEY = self.triggers.ibmcloud_api_key
    }
  }

  provisioner "local-exec" {
    when = destroy

    command = "${path.module}/scripts/delete-gateways.sh '${self.triggers.region}' '${self.triggers.resource_group}' '${self.triggers.subnet_ids}'"

    environment = {
      IBMCLOUD_API_KEY = self.triggers.ibmcloud_api_key
    }
  }
}

resource null_resource list_vpn_gateways {
  depends_on = [null_resource.create_gateway]

  triggers = {
    always_run = timestamp()
    region = var.region
    resource_group = var.resource_group_id
    subnet_ids = join(",", local.subnet_ids)
    ibmcloud_api_key = var.ibmcloud_api_key
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/list-gateways.sh '${self.triggers.region}' '${self.triggers.resource_group}' '${self.triggers.subnet_ids}' '${local.output_file}'"

    environment = {
      IBMCLOUD_API_KEY = self.triggers.ibmcloud_api_key
    }
  }
}

data local_file gateway_output {
  depends_on = [null_resource.create_gateway]

  filename = local.output_file
}

//resource ibm_is_vpn_gateway gateway {
//  count = var.provision ? var.vpc_subnet_count : 0
//
//  name           = "${local.name}${format("%02s", count.index + 1)}"
//  resource_group = var.resource_group_id
//  subnet         = local.subnet_ids[count.index]
//  tags           = concat((var.tags != null ? var.tags : []), [count.index == 0 ? "gateway" : (ibm_is_vpn_gateway.gateway[count.index - 1].id != "" ? "gateway" : "gateway")])
//  mode           = var.mode
//}
