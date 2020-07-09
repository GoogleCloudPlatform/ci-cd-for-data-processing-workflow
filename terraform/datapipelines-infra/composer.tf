# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

locals {
  max_threads        = 2 * var.composer_num_cpus
  worker_concurrency = 6 * var.composer_num_cpus
  parallelism        = (6 * var.composer_num_cpus) * var.composer_node_count
}

resource "google_composer_environment" "orchestration" {
  project = var.project_id
  name    = var.composer_env_name
  region  = var.composer_region

  config {
    node_count = var.composer_node_count

    software_config {
      image_version  = "composer-1.10.6-airflow-1.10.6"
      python_version = "3"

      airflow_config_overrides = {
        # Improves stability when Deleteing DAGs.
        core-dags_are_paused_at_creation = "True"
        # Number of processes to process DAG files
        # estimate = 2*num_cpu_per_node
        scheduler-max_threads = tostring(local.max_threads)
        # Number of celery processes per Airflow worker
        # estimate = num_dags * num_tasks_per_dag * execution_duration_per_task /  dag_ scheduling_period / num_airflow_workers
        #                    |----------------------------------- total  time needed ------------------------------------|
        # or estimate = num_cpu_per_node * 6
        # use lesser of the two estimates
        celery-worker_concurrency = tostring(local.worker_concurrency)
        # The amount of parallelism as a setting to the executor. This defines the max number of task instances that should run simultaneously
        # estimate = worker_concurrency * num_airflow_workers
        core-parallelism = tostring(local.parallelism)
        # The number of task instances allowed to run concurrently by the scheduler
        # estimate = parallelism
        core-dag_concurrency = tostring(local.parallelism)
        # When not using pools, tasks are run in the "default pool", whose size is guided by this config element
        # estimate = parallelism
        core-non_pooled_task_slot_count = tostring(local.parallelism)
        core-store_serialized_dags      = "True"
      }
    }

    node_config {
      zone         = "us-central1-f"
      machine_type = "n1-highmem-${var.composer_num_cpus}"
      disk_size_gb = "30"
      network      = module.vpc.network_self_link
      subnetwork   = module.vpc.subnets["${var.composer_region}/${var.composer_subnet}"].self_link
    }
  }

  depends_on = [google_project_iam_member.composer-worker]
}

resource "google_service_account" "composer_sa" {
  project      = var.project_id
  account_id   = "composer-env-account"
  display_name = "Service Account for Composer Environment"
}

resource "google_project_iam_member" "composer-worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${google_service_account.composer_sa.email}"
}

