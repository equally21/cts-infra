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

# Use public key for ssh access for Ansible
data "local_file" "ssh_key" {
  filename = "${path.module}/id_rsa.pub"
}

# Give argocd access to the k3s clusters
resource "google_compute_firewall" "k3s-api-ssh" {
  name    = "allow-k3s"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["86.61.45.0/24"]
}

# Allow access to the CTS
resource "google_compute_firewall" "cts" {
  name    = "allow-cts"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# Create the VMs
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

# Create the Ansible inventory file
resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl",
    {
      na_ip   = google_compute_instance.vms["na"].network_interface[0].access_config[0].nat_ip
      eu_ip   = google_compute_instance.vms["eu"].network_interface[0].access_config[0].nat_ip
      asia_ip = google_compute_instance.vms["asia"].network_interface[0].access_config[0].nat_ip
    }
  )
  filename = "../ansible/${path.module}/inventory"
}

# Create ArgoCD ApplicationSet
resource "local_file" "ApplicationSet" {
  content = templatefile("${path.module}/templates/application-set.tftpl",
    {
      na_ip   = google_compute_instance.vms["na"].network_interface[0].access_config[0].nat_ip
      eu_ip   = google_compute_instance.vms["eu"].network_interface[0].access_config[0].nat_ip
      asia_ip = google_compute_instance.vms["asia"].network_interface[0].access_config[0].nat_ip
    }
  )
  filename = "../argocd/${path.module}/application-set.yaml"
}