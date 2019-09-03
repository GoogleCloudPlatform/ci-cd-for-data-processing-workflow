# Data Pipelines CI/CD Repo
This repo provides an example of using [Cloud Build](https://cloud.google.com/cloud-build/) 
to deploy various artifacts to deploy GCP D&A technologies. 
The repo includes a Terraform directory to spin up infrastructure as well as 
a Cloud Build Trigger which will automate the deployments of new commits to master.
To fit this to your needs you should create a `terraform.tfvars` file and set the
appropriate values for the variables specified in `terraform/variables.tf`.

## The Cloud Build Process
1. check-out-source-code: Clones the git repo to the Cloud Build environment.
1. build-word-count-jar: Builds a jar for dataflow job using maven.
1. deploy-jar: Copies jar built in previous step to the appropriate location on GCS.
1. test-sql-queries: Dry runs all BigQuery SQL scripts.
1. deploy-sql-queries-for-composer: Copy BigQuery SQL scripts to the Composer Dags bucket in a `dags/sql/` directory.
1. render-airflow-variables: Renders airflow variables based on cloud build parameters to automate deployments across environments.
1. run-unit-tests: Runs an airflow 1.10 image to run unit tests and valiate dags in the Cloud Build environment.
1. deploy-airflowignore: Copies an [`.airflowignore`](https://airflow.apache.org/docs/stable/concepts.html#airflowignore) to ignore non-dag definition files (like sql files) in the dag parser.
1. deploy-test-input-file: Copies a file to GCS (just for example purpose of this DAG)
1. deploy-test-ref-file: Copies a file to GCS (just for example purpose of this DAG)
1. stage-airflow-variables: Copies the rendered AirflowVariables.json file to the Cloud Composer wokers.
1. import-airflow-variables: Imports the rendered AirflowVariables.json file to the Cloud Composer Environment.
1. set-composer-test-jar-ref: Override an aiflow variable that points to the Dataflow jar built durin this run (with this `BUILD_ID`).
1. deploy-custom-plugins: Copy the source code for the Airflow plugins to the `plugins/` directory of the Composer Bucket.
1. stage-for-integration-test: Copy the airflow dags to a `data/test/` directory in the Composer environment for integration test.
1. dag-parse-integration-test: Run `list_dags` on the `data/test/` directory in the Composer environment.
1. clean-up-data-dir-dags: Clean up the integration test artifacts.
1. gcloud-version
1. build-deploydags: Build the golang `deploydags` application (documented in `composer/cloudbuild/README.md`)
1. run-deploydags: Run the deploy dags application.


## Setup Local Development Environment
To setup python dependencies for the pre-commit and running tests:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
python3 -m unittest discover tests
```
### Running Composer Tests Locally
```bash
cd composer
cloudbuild/bin/run_tests.sh
```

## Repo Structure
```
.
├── bigquery
│   ├── cloudbuild
│   ├── cloudbuild.yaml
│   ├── sql
│   │   └── biquery
│   │       └── shakespeare_top_25.sql
│   └── tests
│       └── test_sql.sh
├── cloudbuild
├── cloudbuild.yaml
├── composer
│   ├── cloudbuild
│   │   ├── bin
│   │   │   ├── deploy_dags.sh
│   │   │   └── run_tests.sh
│   │   └── test
│   │       └── cloudbuild.yaml
│   ├── cloudbuild.yaml
│   ├── config
│   │   ├── AirflowVariables.json
│   │   └── running_dags.txt
│   ├── dags
│   │   ├── support-files
│   │   │   ├── input.txt
│   │   │   └── ref.txt
│   │   └── wordcount_dag.py
│   ├── plugins
│   │   └── xcom_utils_plugin
│   │       ├── __init__.py
│   │       ├── operators
│   │       │   ├── compare_xcom_maps.py
│   │       │   └── __pycache__
│   │       │       └── compare_xcom_maps.cpython-36.pyc
│   │       └── __pycache__
│   │           └── __init__.cpython-36.pyc
│   └── tests
│       ├── __pycache__
│       │   ├── test_compare_xcom_maps.cpython-36.pyc
│       │   └── test_dag_validation.cpython-36.pyc
│       ├── test_compare_xcom_maps.py
│       ├── test_compare_xcom_maps.pyc
│       ├── test_dag_validation.py
│       └── test_dag_validation.pyc
├── CONTRIBUTING.md
├── dataflow
│   ├── cloudbuild.yaml
│   └── wordcount
│       ├── pom.xml
│       └── src
│           ├── main
│           │   └── java
│           │       └── org
│           │           └── apache
│           │               └── beam
│           │                   └── examples
│           │                       └── WordCount.java
│           └── test
│               └── java
│                   └── org
│                       └── apache
│                           └── beam
│                               └── examples
│                                   └── WordCountTest.java
├── LICENSE
├── README.md
├── requirements.txt
├── scripts
│   ├── get_composer_properties.sh
│   └── set_env.sh
└── terraform
    ├── cloudbuild.tf
    ├── composer.tf
    ├── gcs.tf
    ├── network.tf
    ├── services.tf
    ├── terraform.tfstate
    ├── terraform.tfstate.backup
    └── variables.tf
```
