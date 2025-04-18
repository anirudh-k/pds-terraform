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

# ~~~~~~~~~~ Cloud Storage ~~~~~~~~~~

resource "google_storage_bucket" "data_lake" {
  name     = "pds-data-lake"
  location = "US"
  project  = var.project
}

# ~~~~~~~~~~ IAM ~~~~~~~~~~

# Service Accounts

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

resource "google_storage_bucket_iam_member" "data_lake_composer_viewer" {
  bucket = google_storage_bucket.data_lake.name
  role   = "roles/storage.objectViewer"
  member = format("serviceAccount:%s", google_service_account.composer_env_sa.email)
}

resource "google_storage_bucket_iam_member" "data_lake_composer_writer" {
  bucket = google_storage_bucket.data_lake.name
  role   = "roles/storage.objectCreator"
  member = format("serviceAccount:%s", google_service_account.composer_env_sa.email)
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

resource "google_composer_environment" "airflow_environment" {
  provider = google
  name     = "airflow"

  config {
    software_config {
      image_version = "composer-3-airflow-2.10.2-build.12"
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

# ~~~~~~~~~~ Secrets Manager ~~~~~~~~~~

resource "google_secret_manager_secret" "airflow-gcp-project-id" {
  secret_id = "airflow-variables-gcp-project-id"

  replication {
    auto {}
  }
}


resource "google_secret_manager_secret_version" "airflow-gcp-project-id" {
  secret = google_secret_manager_secret.airflow-gcp-project-id.id

  secret_data_wo = "personal-data-stack"
}