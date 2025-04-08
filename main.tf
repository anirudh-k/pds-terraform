resource "google_project" "personal_data_stack" {
  auto_create_network = true
  billing_account     = "01886D-30C822-5FBA01"
  deletion_policy     = "PREVENT"
  folder_id           = null
  labels              = {}
  name                = "Personal Data Stack"
  org_id              = null
  project_id          = "personal-data-stack"
  tags                = null
}

# ~~~~~~~~~~ Cloud Composer ~~~~~~~~~~

locals {
  required_apis = {
    composer = "composer.googleapis.com"
    secrets  = "secretmanager.googleapis.com"
  }
}

resource "google_project_service" "apis" {
  for_each = local.required_apis
  
  provider = google
  project  = var.project
  service  = each.value

  disable_on_destroy = false
}

resource "google_service_account" "composer_env_sa" {
  provider     = google
  account_id   = "composer-env-service-account"
  display_name = "Composer Environment Service Account"
}

resource "google_project_iam_member" "composer_env_sa" {
  provider = google
  project  = var.project
  member   = format("serviceAccount:%s", google_service_account.composer_env_sa.email)
  role     = "roles/composer.worker"
}

resource "google_composer_environment" "airflow_environment" {
  provider = google
  name     = "airflow"

  config {

    software_config {
      image_version = "composer-3-airflow-2.10.2-build.12"
    }

    database_config {
      zone = var.zone
    }

    workloads_config {

      scheduler {
        cpu        = 1
        memory_gb  = 2.5
        storage_gb = 2
        count      = 1
      }
      triggerer {
        count     = 1
        cpu       = 0.5
        memory_gb = 1
      }
      web_server {
        cpu        = 1
        memory_gb  = 2.5
        storage_gb = 2
      }
      worker {
        cpu        = 1
        memory_gb  = 2
        storage_gb = 2
        min_count  = 2
        max_count  = 4
      }
    }

    environment_size = "ENVIRONMENT_SIZE_SMALL"

    node_config {
      service_account = google_service_account.composer_env_sa.email
    }

  }

  labels = {
    owner   = "data-platform"
    env     = "dev"
    service = "airflow"
  }
}