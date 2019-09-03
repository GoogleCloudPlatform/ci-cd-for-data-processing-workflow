module "data_buckets" {
  source     = "terraform-google-modules/cloud-storage/google"
  version    = "~> 0.1"
  project_id = "${var.project_id}"

  prefix = "${var.project_id}"

  names = [
    "wordcount_input",
    "wordcount_result",
    "wordcount_ref",
  ]

  versioning = {
    first = true
  }

  creators = [
    "serviceAccount:${google_service_account.composer_sa.email}",
  ]

  viewers = [
    "serviceAccount:${google_service_account.composer_sa.email}",
  ]
}

module "dataflow_buckets" {
  source     = "terraform-google-modules/cloud-storage/google"
  version    = "~> 0.1"
  project_id = "${var.project_id}"

  prefix = "${var.project_id}"

  names = [
    "dataflow_jars",
    "dataflow_staging",
  ]

  versioning = {
    first = true
  }

  creators = [
    "serviceAccount:${google_service_account.composer_sa.email}",
  ]

  viewers = [
    "serviceAccount:${google_service_account.composer_sa.email}",
  ]
}
