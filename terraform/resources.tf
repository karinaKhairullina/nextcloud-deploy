
# Создание сети
resource "yandex_vpc_network" "network" {
  name = "${var.project_name}-network"
}

# Создание подсети
resource "yandex_vpc_subnet" "subnet" {
  name           = "${var.project_name}-subnet"
  v4_cidr_blocks = ["192.168.10.0/24"]
  network_id     = yandex_vpc_network.network.id
  zone           = var.zone
}

# Группа безопасности
resource "yandex_vpc_security_group" "nextcloud_sg" {
  name        = "${var.project_name}-sg"
  network_id  = yandex_vpc_network.network.id

  # Входящие правила (ingress)
  ingress {
    description = "SSH access for management"
    port        = 22
    protocol    = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "HTTP access for Nextcloud"
    port        = 80
    protocol    = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  ingress {
    description = "HTTPS access for Nextcloud"
    port        = 443
    protocol    = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  # Исходящие правила (egress)
  egress {
    description = "Allow outbound HTTP traffic for APT"
    protocol    = "TCP"
    port        = 80
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow outbound HTTPS traffic for APT"
    protocol    = "TCP"
    port        = 443
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow outbound DNS traffic"
    protocol    = "UDP"
    port        = 53
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow all outbound TCP traffic"
    protocol    = "TCP"
    port        = 0 
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound UDP traffic"
    protocol    = "UDP"
    port        = 0 
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    description = "Allow all outbound ICMP traffic"
    protocol    = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }
}

# Виртуальная машина
resource "yandex_compute_instance" "nextcloud_vm" {
  name                  = "${var.project_name}-vm"
  platform_id           = "standard-v3"
  folder_id             = var.folder_id
  zone                  = var.zone
  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd80ok8sil1fn2gqbm6h" # Ubuntu 22.04
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.nextcloud_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = self.network_interface.0.nat_ip_address
    private_key = file("~/.ssh/id_rsa")
    timeout     = "2m"
  }

  provisioner "local-exec" {
    command = "echo ${self.network_interface.0.nat_ip_address} > inventory.ini"
  }
}

# Создание DNS-зоны
resource "yandex_dns_zone" "public_zone" {
  name = "vvot44-public-zone" 
  zone = "vvot44.itiscl.ru."  
  public = true               
}


resource "yandex_dns_recordset" "nextcloud_record" {
  zone_id = yandex_dns_zone.public_zone.id 
  name    = "project"                     
  type    = "A"
  ttl     = 300
  data    = [yandex_compute_instance.nextcloud_vm.network_interface.0.nat_ip_address] 
}
