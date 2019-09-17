# CI/CD for data processing workflow

This repository contains source code for the guide on how to use Cloud Build and
Cloud Composer to create a CI/CD pipeline for automated testing, building, and
deployment of a data processing workflow.

Please refer to the solution guide for the steps to run the code: [solution
tutorial](https://cloud.google.com/solutions/cicd-pipeline-for-data-processing)

## Set Up

The folllowing commands will:
 - Set the necessary environment variables for this example locally
 - Create the necessary GCS Buckets
 - Create a Cloud Composer Environment
 - Set up a python3 virtual environment with dependencies for local 
 development and testing.

```bash
source env-setup/set_env.sh

chmod +x env-setup/create_buckets.sh \
  env-setup/create_composer_environment.sh \
  env/set_build_iam.sh

./env-setup/create_buckets.sh
./env-setup/set_build_iam.sh
./env-setup/create_composer_environment.sh ## This will take a while.

source env-setup/get_composer_properties.sh

python3 -m venv airflow-venv
source airflow-venv/bin/activate
pip3 install -r requirements.txt
```

## Running Tests Locally

The following commands will set airflow up locally and run the unit tests in the
`souce-code/tests/` directory as well as a DAG validation test.

DAG Validation will check for:
 - Syntax errors
 - Dependency cycles
 - Referencing Variables or Connections that do not exist in your Cloud Composer
 environment
 - Referencing SQL files that don't exist
 - DAGs that take more 2 seconds to parse. This is a safety measure as these can
 be problematic for the airflow scheduler and is a sign that some expensive /
 long-running piece of code is being run in the DAG definition file which is an
 anti-pattern and should be refactored.

```bash
cd source_code
chmod +x build_pipeline/run_tests.sh
./build_pipeline/run_tests.sh
```

## Deploying with Cloud Build

The [`cloud_build.yaml`](./cloud_build.yaml) file defines a series of steps to
validate and build the code in your repo. It contains several replacement
variables that can be convienently read from the environment variables (from 
`set_env.sh` and `get_composer_properties.sh`) using the `BUILD` script.

If any of the a step fails the subsequent steps will not be attempted.
This is why it is imporant that we order things so our code artifacts are
validated before they are deployed. Note, that cloud build doesn't roll back
in the event of failure. One can roll back by reverting to an old commit and
running the Cloud Build pipeline again.

The important high level steps are as follows:
 1. Clone your repo from Cloud Source Repositories.
 1. Build a jar for your batch data processing source code (in this case a
 Dataflow job but this could be a MapReduce or Spark job).
 1. Deploy the data processing jar with a unique Build ID suffix in GCS.
 1. Dry run all the BigQuery SQL scripts in `source-code/dags/sql`.
 1. Deploy the the SQL scripts to GCS in the dags folder for the Cloud Composer
 environment.
 1. Run the unit tests and DAG validation tests (same as described in
 "Running Tests Locally").
 1. Stage `config/Variables.json` in the data directory on GCS (synced to the
 Composer workers).
 1. Import airflow variables from the file staged in previous step.
 1. Deploy Custom Plugins.
 1. Use `build_pipeline/deploy_dags.sh` to:
   - Pause and delete the DAGs in the Composer Environment with `dag_id`s that
   are not present in `config/running_dags.txt`.
   - Deploy and unpause DAGs that are absent in the Composer Environment with
   `dag_id`s that are present in `config/running_dags.txt`.
   - Validate that the source code has not changed for any DAGs in
   `config/running_dags.txt` that is already active in the Cloud Composer
   Environment.


There are some additional steps specific to this example like staging additional
support files in GCS and triggering a run of the newly deployed `prod_word_count` DAG.

