# Artifacts and Cloud Build
The terraform in this dir handles the infrastructure for building and storing 
artifacts that are built in the CI environment and used in the production environment.
## Requirements

No requirements.

## Providers

| Name | Version |
|------|---------|
| google | n/a |
| google-beta | n/a |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ci\_composer\_env | n/a | `string` | `""` | no |
| ci\_project | Continuous Integration Project which pushes artifacts | `any` | n/a | yes |
| prod\_project | Production project which pulls artifacts | `any` | n/a | yes |
| project\_id | Project ID for your GCP project to store artifacts | `any` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| dataflow\_artifacts\_bucket | n/a |

