# Datapipelines Infrastructure Module
Module to DRY up infrastructure for CI and prod datapipelines environments.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.12 |

## Providers

| Name | Version |
|------|---------|
| google | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| artifacts\_project | project to push artifacts for successful post commits | `any` | n/a | yes |
| composer\_env\_name | Composer Environment name | `string` | `"datapipelines-orchestration"` | no |
| composer\_region | Region for your composer environment | `string` | `"us-central1"` | no |
| composer\_subnet | Name for composer subnetwork to create | `string` | `"composer-subnet"` | no |
| env | Environment name ie. dev, test, prod | `string` | `""` | no |
| network\_name | The network your data pipelines should use | `string` | `"datapipelines-net"` | no |
| project\_id | Project ID for your GCP project to run CI tests | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| cloudbuild-sa | The Cloud build SA for the project created by this module |
| composer-env | The Cloud Composer Environment created by this module |
| project | The project created by this module |
| vpc | The VPC network created by this module |

