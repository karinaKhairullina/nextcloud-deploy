
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

  ingress {
    description = "SSH access for management"
    port        = 22
    protocol    = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"] # Разрешить SSH из любой точки (можно ограничить)
  }

  ingress {
    description = "HTTP access for Nextcloud"
    port        = 80
    protocol    = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"] # Разрешить HTTP из любой точки
  }

  ingress {
    description = "HTTPS access for Nextcloud"
    port        = 443
    protocol    = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"] # Разрешить HTTPS из любой точки
  }

  egress {
    description = "Allow all outbound TCP traffic"
    protocol    = "TCP"
    port        = 0 # Разрешить все порты
    v4_cidr_blocks = ["0.0.0.0/0"] # Разрешить исходящий трафик в интернет
  }

  egress {
    description = "Allow all outbound UDP traffic"
    protocol    = "UDP"
    port        = 0 # Разрешить все порты
    v4_cidr_blocks = ["0.0.0.0/0"] # Разрешить исходящий трафик в интернет
  }

  egress {
    description = "Allow all outbound ICMP traffic"
    protocol    = "ICMP"
    v4_cidr_blocks = ["0.0.0.0/0"] # Разрешить ICMP для диагностики
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