# Terraform Automation Source


## Introduction

This repository contains the terraform modules which helps in automating the GCP resource creation. These terraform module will create
- Cloud Composer
- GCS bucket
- Cloud Build Trigger
- Cloud Source Repository
- Service Account for Cloud Composer
- Pub-Sub respource
- Network resources like VPC and Subnet
- Enable Google API's

## Pre requistie

1. You must have a GCP project created with `project owner` permissions.
2. Terraform and Gcloud cli are installed in your machine.

## Execution

1. git clone this repository and `cd ci-cd-for-data-processing-workflow/example/1.terraform-automation`.
2. Perform a gcloud login using `gcloud auth application-default login`
3. Update `terraform.tfvars` with the values.
4. Execute `terraform init`
5. Execute `terraform plan` and validate the resources displayed in the output.
6. Execute `terraform apply` and confirm with `yes` when asked to create resources in your google project.
7. Once the above steps complete, you would have created the GCP resources listed in the `Introduction` section. You should now also be able to see the two source code repositories created in your project, one for the `terraform-automation-source` and another for the `data-pipeline-source`.
8. You can now push the three folders(build-pipeline, data-processing-code, workflow-dag) present inside the `source-code` folder ([link](https://github.com/parasmamgain/ci-cd-for-data-processing-workflow/tree/master/source-code)) in the Code Source repository created with the name `data-pipeline-source`.
9. Code push will trigger the Cloudbuild trigger which would create the jobs inside the cloud composer created via the terraform.


## Disclaimer

Copyright 2022 Google. This software is provided as-is, without warranty or representation for any use or purpose.
Your use of it is subject to your agreement with Google.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| <a name="provider_google"></a> [google](#provider\_google) | 4.44.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_composer"></a> [composer](#module\_composer) | terraform-google-modules/composer/google//modules/create_environment_v2 | n/a |
| <a name="module_composer-service-accounts"></a> [composer-service-accounts](#module\_composer-service-accounts) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/iam-service-account | v18.0.0/ |
| <a name="module_gcs_buckets_prod"></a> [gcs\_buckets\_prod](#module\_gcs\_buckets\_prod) | terraform-google-modules/cloud-storage/google | n/a |
| <a name="module_gcs_buckets_test"></a> [gcs\_buckets\_test](#module\_gcs\_buckets\_test) | terraform-google-modules/cloud-storage/google | n/a |
| <a name="module_pubsub"></a> [pubsub](#module\_pubsub) | terraform-google-modules/pubsub/google | ~> 1.8 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | github.com/GoogleCloudPlatform/cloud-foundation-fabric//modules/net-vpc | v18.0.0/ |

## Resources

| Name | Type |
|------|------|
| [google_cloudbuild_trigger.trigger-build-in-prod-environment](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger) | resource |
| [google_cloudbuild_trigger.trigger-build-in-test-environment](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloudbuild_trigger) | resource |
| [google_project_iam_member.cloudbuild_sa](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [google_project_service.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |
| [google_sourcerepo_repository.my-repo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sourcerepo_repository) | resource |
| [google_sourcerepo_repository.tf-source-repo](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sourcerepo_repository) | resource |
| [google_project.project](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_composer_dag_name_prod"></a> [composer\_dag\_name\_prod](#input\_composer\_dag\_name\_prod) | The Composer DAG name(for prod) to be passed as environment variable. | `string` | `"prod_word_count"` | no |
| <a name="input_composer_dag_name_test"></a> [composer\_dag\_name\_test](#input\_composer\_dag\_name\_test) | The Composer DAG name(for test) to be passed as environment variable. | `string` | `"test_word_count"` | no |
| <a name="input_composer_env_name"></a> [composer\_env\_name](#input\_composer\_env\_name) | Name of Cloud Composer Environment | `string` | `"composer-dev-env"` | no |
| <a name="input_composer_zone_id"></a> [composer\_zone\_id](#input\_composer\_zone\_id) | Zone value which is passed to the Airflow envt | `string` | `"us-central1-a"` | no |
| <a name="input_datapipeline_csr_name"></a> [datapipeline\_csr\_name](#input\_datapipeline\_csr\_name) | The CSR repo name to be used for storing the datapipeline source code. | `string` | `"data-pipeline-source"` | no |
| <a name="input_image_version"></a> [image\_version](#input\_image\_version) | The version of the aiflow running in the cloud composer environment. | `string` | `"composer-2.0.32-airflow-2.3.4"` | no |
| <a name="input_network"></a> [network](#input\_network) | The VPC network to host the composer cluster. | `string` | `"default"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Project ID where Cloud Composer Environment is created. | `string` | n/a | yes |
| <a name="input_pubsub_topic"></a> [pubsub\_topic](#input\_pubsub\_topic) | Name of the pub sub topic. | `string` | `"integration-test-complete-topic"` | no |
| <a name="input_region"></a> [region](#input\_region) | Region where the Cloud Composer Environment is created. | `string` | `"us-central1"` | no |
| <a name="input_subnetwork"></a> [subnetwork](#input\_subnetwork) | The subnetwork to host the composer cluster. | `string` | `"default"` | no |
| <a name="input_terraform_deployment_csr_name"></a> [terraform\_deployment\_csr\_name](#input\_terraform\_deployment\_csr\_name) | The CSR repo name to be used for storing the terraform code. | `string` | `"terraform-automation-source"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_composer"></a> [composer](#output\_composer) | Information about the cloud composer resource which is created |
<!-- END_TF_DOCS -->
