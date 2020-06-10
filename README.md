# Data Pipelines CI/CD Repo
This repo provides an example of using [Cloud Build](https://cloud.google.com/cloud-build/) 
to deploy various artifacts to deploy GCP D&A technologies. 
The repo includes a Terraform directory to spin up infrastructure as well as 
a Cloud Build Trigger which will automate the deployments of new commits to master.
To fit this to your needs you should create a `terraform.tfvars` file and set the
appropriate values for the variables specified in `terraform/variables.tf`.

## Project Structure
This example focuses on CI checks on PRs, Artifact staging and production deployment.
1. CI: Houses infrastructure similar  to production to facilitate Continuous Integration tests on 
PRs.
1. Aritfacts: Houses built artifacts (such as images, executables, etc.) that passed all CI checks.
Pushed from CI; Pulled from Prod.
1. Production: Where the workload runs that actually serves the business.

The formal [similarity](https://en.wikipedia.org/wiki/Similarity_(geometry)) between CI and
production is enforced as they are provisioned with terraform with different variables. 
This includes pointing to different projects / buckets. This might include sizing differences in 
Composer environment for production scale workload.

To update CI infrastructure
```
terraform apply -var-file=ci.tfvars
```

To update Production infrastructure
```
terraform apply -var-file=prod.tfvars
```

CI/CD for IaC is a topic of it's own and is only included here for reproducibility.

In many organizations, there is a concept of "QA" or "Staging" project / environment where additional
manual validation is done. The concepts in this repo can be extended to accomodate such a structure
by invoking the `cd/prod.yaml` with the appropriate susbstitutions for your QA / Staging environment.

## Flow
### Development Flow
1. Open PR.
1. Maintainer's `/gcbrun` comment triggers CI process (below) in CI project.
1. Fix anything that is causing the build to fail (this could include adding build steps).
1. On successful CI run pushes artifacts to the artifacts project. Images go to GCR, JARs go to GCS 
with a `BUILD_ID` prefix.

### Deployment Flow
1. Cut and tag a release branch and run `cd/release.yaml` this runs the CI process again 
(this ensures there were no issues due to merges) and pushes the artifacts to the artifacts project.
1. Run `cd/prod.yaml` to deploy the release branch to production project this must include a 
substitution `_RELEASE_BUILD_ID` so it knows what version of the artifacts to pull in.

## The Cloud Build CI Process
1. run-style-and-unit-tests: Runs linters(yapf, go fmt, terraform fmt, google-java-format), 
static code analysis (shellcheck, flake8, go vet) and unit tests.
1. build-word-count-jar: Builds a jar for dataflow job using maven.
1. deploy-jar: Copies jar built in previous step to the appropriate location on GCS.
1. test-sql-queries: Dry runs all BigQuery SQL scripts.
1. deploy-sql-queries-for-composer: Copy BigQuery SQL scripts to the Composer Dags bucket in a 
`dags/sql/` directory.
1. render-airflow-variables: Renders airflow variables based on cloud build parameters to automate 
deployments across environments.
1. run-unit-tests: Runs an airflow 1.10 image to run unit tests and valiate dags in the Cloud Build environment.
1. deploy-airflowignore: Copies an [`.airflowignore`](https://airflow.apache.org/docs/stable/concepts.html#airflowignore)
to ignore non-dag definition files (like sql files) in the dag parser.
1. deploy-test-input-file: Copies a file to GCS (just for example purpose of this DAG)
1. deploy-test-ref-file: Copies a file to GCS (just for example purpose of this DAG)
1. stage-airflow-variables: Copies the rendered AirflowVariables.json file to the Cloud Composer wokers.
1. import-airflow-variables: Imports the rendered AirflowVariables.json file to the Cloud Composer Environment.
1. set-composer-test-jar-ref: Override an aiflow variable that points to the Dataflow jar built 
during this run (with this `BUILD_ID`).
1. deploy-custom-plugins: Copy the source code for the Airflow plugins to the `plugins/` directory of
the Composer Bucket.
1. stage-for-integration-test: Copy the airflow dags to a `data/test/` directory in the Composer 
environment for integration test.
1. dag-parse-integration-test: Run `list_dags` on the `data/test/` directory in the Composer
environment.
1. clean-up-data-dir-dags: Clean up the integration test artifacts.
1. gcloud-version
1. build-deploydags: Build the golang `deploydags` application 
(documented in `composer/cloudbuild/README.md`)
1. run-deploydags: Run the deploy dags application.


## Setup Local Development Environment

To setup python dependencies for the pre-commit and running tests:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
python3 -m unittest discover tests
```

### Formatting Code Locally
Runs `go fmt`, `yapf`, `google-java-format`, `terraform fmt` on appropriate files.
```bash
make fmt
```

### Running Tests Locally
Runs linters, static code analysis and unit tests.
```bash
make test
```

### Pushing a new version of the deploydags golang application
Changes to the deploydags golang app can be pushed with
```bash
make push_deploydags_image
```

## Repo Structure
```
.
├── bigquery
│   ├── sql
│   │   └── shakespeare_top_25.sql
│   └── tests
│       └── test_sql.sh
├── ci
│   └── Dockerfile
├── cloudbuild.yaml
├── composer
│   ├── cloudbuild
│   │   ├── bin
│   │   │   └── run_tests.sh
│   │   ├── go
│   │   │   └── dagsdeployer
│   │   │       ├── cmd
│   │   │       │   └── deploydags
│   │   │       │       └── main.go
│   │   │       ├── Dockerfile
│   │   │       ├── go.mod
│   │   │       ├── go.sum
│   │   │       └── internal
│   │   │           ├── composerdeployer
│   │   │           │   ├── composer_ops.go
│   │   │           │   └── composer_ops_test.go
│   │   │           └── gcshasher
│   │   │               ├── gcs_hash.go
│   │   │               ├── gcs_hash_test.go
│   │   │               └── testdata
│   │   │                   ├── test_diff.txt
│   │   │                   └── test.txt
│   │   ├── Makefile
│   │   └── README.md
│   ├── config
│   │   ├── AirflowVariables.json
│   │   └── running_dags.txt
│   ├── dags
│   │   ├── support-files
│   │   │   ├── input.txt
│   │   │   └── ref.txt
│   │   ├── tutorial.py
│   │   └── wordcount_dag.py
│   ├── deploydags
│   ├── plugins
│   │   └── xcom_utils_plugin
│   │       ├── __init__.py
│   │       └── operators
│   │           └── compare_xcom_maps.py
│   ├── requirements-dev.txt
│   └── tests
│       ├── test_compare_xcom_maps.py
│       └── test_dag_validation.py
├── CONTRIBUTING.md
├── dataflow
│   └── java
│       └── wordcount
│           ├── pom.xml
│           └─── src
│               ├── main
│               │   └── java
│               │       └── org
│               │           └── apache
│               │               └── beam
│               │                   └── examples
│               │                       └── WordCount.java
│               └── test
│                   └── java
│                       └── org
│                           └── apache
│                               └── beam
│                                   └── examples
│                                       └── WordCountTest.java
├── helpers
│   ├── check_format.sh
│   ├── exclusion_list.txt
│   ├── format.sh
│   └── run_tests.sh
├── LICENSE
├── license-templates
│   └── LICENSE.txt
├── Makefile
├── README.md
├── scripts
│   ├── get_composer_properties.sh
│   └── set_env.sh
└── terraform
    ├── cloudbuild.tf
    ├── composer.json
    ├── composer.tf
    ├── errored.tfstate
    ├── gcs.tf
    ├── network.tf
    ├── services.tf
    ├── variables.tf
    └── versions.tf

64 directories, 69 files
```
