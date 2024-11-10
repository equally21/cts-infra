provider "google" {
  project = "linear-element-441213-b1"
  region  = "us-central1"
}

locals {
  regions = {
    na = "us-central1"
    eu = "europe-west4"
    asia = "asia-east1"
  }
}

data "local_file" "ssh_key" {
  filename = "${path.module}/id_rsa.pub"
}

resource "google_compute_firewall" "k3s" {
  name    = "allow-k3s"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["86.61.45.0/24"]
}

resource "google_compute_firewall" "k3s" {
  name    = "allow-cts"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "vms" {
  for_each = local.regions

  name         = "vm-${each.key}"
  machine_type = "e2-medium"
  zone         = "${each.value}-b"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata = {
    ssh-keys = "debian:${data.local_file.ssh_key.content}"
  }
}

output "instance_ips" {
  value = {
    for k, v in google_compute_instance.vms : k => {
      external_ip = v.network_interface[0].access_config[0].nat_ip
    }
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/inventory.tpl",
    {
      na_ip   = google_compute_instance.vms["na"].network_interface[0].access_config[0].nat_ip
      eu_ip   = google_compute_instance.vms["eu"].network_interface[0].access_config[0].nat_ip
      asia_ip = google_compute_instance.vms["asia"].network_interface[0].access_config[0].nat_ip
    }
  )
  filename = "${path.module}/inventory"
}