# Network ресурсы
resource "yandex_vpc_network" "my_network" {
  name = var.yc_network_name
}

resource "yandex_vpc_subnet" "subnet" {
  name           = var.yc_subnet_name
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.my_network.id
  v4_cidr_blocks = [var.yc_subnet_range]
  route_table_id = yandex_vpc_route_table.route_table.id
}

resource "yandex_vpc_gateway" "nat_gateway" {
  name = var.yc_nat_gateway_name
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "route_table" {
  name       = var.yc_route_table_name
  network_id = yandex_vpc_network.my_network.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat_gateway.id
  }
}

resource "yandex_vpc_security_group" "security_group" {
  name        = var.yc_security_group_name
  description = "Security group for Dataproc cluster"
  network_id  = yandex_vpc_network.my_network.id

  ingress {
    protocol       = "ANY"
    description    = "Allow all incoming traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "UI"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Jupyter"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 8888
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outgoing traffic"
    from_port      = 0
    to_port        = 65535
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol          = "ANY"
    description       = "Internal"
    from_port         = 0
    to_port           = 65535
    predefined_target = "self_security_group"
  }
}


# compute ресурсы
resource "yandex_compute_instance" "proxy" {
  boot_disk {
    initialize_params {
      name       = "disk-ubuntu-20-04-for-proxy"
      type       = "network-ssd"
      size       = 10
      block_size = 4096
      image_id   = "fd87q9coi4v2ap1c9okf"
    }
    auto_delete = true
  }
  folder_id = var.yc_folder_id
  hostname  = "compute-vm-2-2-10-ssd-1783175271593"
  metadata = {
    user-data = "#cloud-config\ndatasource:\n Ec2:\n  strict_id: false\nssh_pwauth: no\nusers:\n- name: ubuntu\n  sudo: ALL=(ALL) NOPASSWD:ALL\n  shell: /bin/bash\n  ssh_authorized_keys:\n  - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG1DB0k45xC+EYl54R0YKEehQrnU0AhEIVloB3SbF8jS https://github.com/ArthurKaplanov"
    ssh-keys  = "ubuntu:ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG1DB0k45xC+EYl54R0YKEehQrnU0AhEIVloB3SbF8jS https://github.com/ArthurKaplanov"
  }
  name                      = "proxy"
  allow_stopping_for_update = true

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.security_group.id]
  }
  platform_id = "standard-v3"
  resources {
    memory        = 2
    cores         = 2
    core_fraction = 100
  }
  scheduling_policy {
    preemptible = true
  }
  zone = var.yc_zone
}

#IAM service 
data "yandex_iam_service_account" "hw3-service" {
  name = var.yc_service_account_name
}

# Dataproc ресурсы
resource "yandex_dataproc_cluster" "dataproc_cluster" {
  bucket      = var.yc_bucket_name
  description = "Dataproc Cluster created by Terraform for OTUS HW 3"
  name        = var.yc_dataproc_cluster_name
  labels = {
    created_by = "terraform"
  }
  service_account_id = data.yandex_iam_service_account.hw3-service.id
  zone_id            = var.yc_zone
  security_group_ids = [yandex_vpc_security_group.security_group.id]


  cluster_config {
    version_id = var.yc_dataproc_version

    hadoop {
      services = ["HDFS", "YARN", "SPARK", "HIVE", "TEZ"]
      properties = {
        "yarn:yarn.resourcemanager.am.max-attempts" = 5
      }
      ssh_public_keys = [file(var.public_key_path)]
    }

    subcluster_spec {
      name = "master"
      role = "MASTERNODE"
      resources {
        resource_preset_id = var.dataproc_master_resources.resource_preset_id
        disk_type_id       = var.dataproc_master_resources.disk_type_id
        disk_size          = var.dataproc_master_resources.disk_size
      }
      subnet_id        = yandex_vpc_subnet.subnet.id
      hosts_count      = 1
      assign_public_ip = true
    }

    subcluster_spec {
      name = "data"
      role = "DATANODE"
      resources {
        resource_preset_id = var.dataproc_data_resources.resource_preset_id
        disk_type_id       = var.dataproc_data_resources.disk_type_id
        disk_size          = var.dataproc_data_resources.disk_size
      }
      subnet_id   = yandex_vpc_subnet.subnet.id
      hosts_count = 3
    }
  }
}