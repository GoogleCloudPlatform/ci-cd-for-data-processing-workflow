# Data Pipelines CI/CD Mono Repo
This repo provides an example of using [Cloud Build](https://cloud.google.com/cloud-build/) 
to deploy various artifacts to deploy GCP D&A technologies. 
The repo includes a Terraform directory to spin up infrastructure as well as 
Cloud Build Triggers which will automate the deployments of new commits to
master.

## GCP Project Structure
This example focuses on CI checks on PRs, Artifact staging and production deployment.
1. CI: Houses infrastructure similar  to production to facilitate Continuous 
Integration tests on PRs.
1. Aritfacts: Houses built artifacts (such as images, executables, etc.) that
passed all CI checks. Pushed from CI; Pulled from Prod.
1. Production: Where the workload runs that actually serves the business.

The formal [similarity](https://en.wikipedia.org/wiki/Similarity_(geometry))
between CI and production is enforced as they are provisioned with terraform 
with different inputs. 
This includes pointing to different projects / buckets. This might include
sizing differences in  Composer environment for production scale workload.

This project uses [terragrunt](https://terragrunt.gruntwork.io/) to manage all
ci, artifacts and production projects keep terraform configs and backends DRY
and handle passing dependencies between the terraform states. This was chosen as
an OSS alternative to terraform enterprise.

CI/CD for IaC is a topic of it's own and is only included here for
reproducibility and examples sake.

In many organizations, there is a concept of "QA" or "Staging" project / 
environment where additional manual validation is done.
The concepts in this repo can be extended to accomodate such a structure
by adding a directory under terraform with a `terragrunt.hcl` file that
handles inputs and dependencies.

## Flow
### Development Flow
1. Prepare changes and run `make test` to run static / unit tests locally.
1. Open PR. Unit and style checks will run automatically.
1. Maintainer's `/gcbrun` comment triggers CI process (below) in CI project.
1. Fix anything that is causing the build to fail (this could include adding
new build steps if necessary).
1. On successful CI run pushes artifacts to the artifacts project.
Images go to GCR, JARs go to GCS with a `SHORT_SHA` prefix.

### Deployment Flow
Run any necessary large scale integration testing or manual confirmation of the
CI environment. These tests do not fit comfortably in the Cloud Build  10 minute
timeout and were out of scope for this example but could also be automated in a
more persistent CI framework like spinnaker, jenkins or gitlab.
Run the root cloudbuild with the production substitution values.

## Precommit and Postcommit "Discovery"
Each directory in this repo containing code to be tested with a precommit and/or
deployed  with a post commit can be picked up by the build discovery script
defined in `./helpers/run_relevant_cloudbuilds.sh` by defining the following:
1. a `precommit_cloudbuild.yaml`: defines unit tests and static analysis beyond 
what the repo enforces.
1. a `cloudbuild.yaml`: integration tests, deploys artifacts and updates
necessary references for System Tests. For example build a dataflow jar and
update the Airflow Variable in Composer Environment that tells the DAG what jar
to run.

All nested cloudbuilds should assume they run from the root of the repo and set
`dir` accordingly.

#### Precommit
The precommit should run without substitutions.

### Cloud Build
The Cloud Build should accept the following substitutions:
- `_COMPOSER_REGION`
- `_COMPOSER_ENV_NAME`
- `_DATAFLOW_JAR_BUCKET`

The precommit will be run on every PR including changes under that file tree.
The build will deploy to the CI environment on a "/gcbrun" comment.

## The Cloud Build CI Process
1. init-git-repo: initialize the git repository.
1. merge-master: merge to master branch so we test post merge code.
1. run-builds: search for post commit `cloudbuild.yaml`s to run using `helpers/run_relevant_cloudbuilds.sh`
1. deploy-sql-queries-for-composer: Copy the BigQuery SQL to the dags folder of the target Composer Environment.
1. deploy-airflowignore: Copies an [`.airflowignore`](https://airflow.apache.org/docs/stable/concepts.html#airflowignore)
to ignore non-dag definition files (like sql files) in the dag parser.
1. deploy-test-input-file: Copies a file to GCS (just for example purpose of this DAG)
1. deploy-test-ref-file: Copies a file to GCS (just for example purpose of this DAG)
1. stage-airflow-variables: Copies the rendered AirflowVariables.json file to the Cloud Composer wokers.
1. import-airflow-variables: Imports the rendered AirflowVariables.json file to the Cloud Composer Environment.
1. deploy-custom-plugins: Copy the source code for the Airflow plugins to the `plugins/` directory of
the Composer Bucket.
1. stage-for-integration-test: Copy the airflow dags to a `data/test/` directory in the Composer 
environment for integration test.
1. dag-parse-integration-test: Run `list_dags` on the `data/test/` directory in the Composer
environment. This is validates that dags don't refer to variables or connections that don't exist in the target environment
1. clean-up-data-dir-dags: Clean up the integration test artifacts.
1. pull-deploydags: pull the existing deploydags image (to facilitate caching if possible).
1. build-deploydags: Build the golang `deploydags` application 
(documented in `composer/cloudbuild/README.md`)
1. run-deploydags: Run the deploy dags application.


## Setup Cloud Shell Development Environment (for example's sake)
Install terragrunt and ensure java 8.
```bash
sudo ./helpers/init_cloudshell.sh
```
<!---  TODO(jaketf): clean this up / make more general --->

You can confirm things look roughly like this:
```
# Python for airflow / beam development
$ python3 --version
Python 3.7.3

# Java for beam development
$ mvn -version
mvn -version
Apache Maven 3.6.3 (cecedd343002696d0abb50b32b541b8a6ba2883f)
Maven home: /opt/maven
Java version: 1.8.0_232, vendor: Oracle Corporation, runtime: /usr/lib/jvm/java-8-openjdk-amd64/jre
Default locale: en_US, platform encoding: UTF-8
OS name: "linux", version: "4.19.112+", arch: "amd64", family: "uni"

# Golang for modifying deploydags app
$ go version
go version go1.14.4 linux/amd64

# Terragrunt / Terraform for IaC for the projects
$ terraform -version
Terraform v0.12.24

$ terragrunt -version
terragrunt version v0.23.24
```

To setup python dependencies for running the tests:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cd composer
python3 -m  pytest
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
│   ├── precommit_cloudbuild.yaml
│   ├── README.md
│   ├── sql
│   │   └── shakespeare_top_25.sql
│   └── tests
│       └── test_sql.sh
├── cd
│   └── prod.yaml
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
│   │   │       │       ├── deploydags
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
│   │   └── ci_dags.txt
│   ├── dags
│   │   ├── support-files
│   │   │   ├── input.txt
│   │   │   └── ref.txt
│   │   ├── tutorial.py
│   │   └── wordcount_dag.py
│   ├── deploydags
│   ├── __init__.py
│   ├── plugins
│   │   └── xcom_utils_plugin
│   │       ├── __init__.py
│   │       ├── operators
│   │       │   ├── compare_xcom_maps.py
│   │       │   ├── __init__.py
│   │       │   └── __pycache__
│   │       │       ├── compare_xcom_maps.cpython-37.pyc
│   │       │       └── __init__.cpython-37.pyc
│   │       └── __pycache__
│   │           └── __init__.cpython-37.pyc
│   ├── precommit_cloudbuild.yaml
│   ├── __pycache__
│   │   └── __init__.cpython-37.pyc
│   ├── requirements-dev.txt
│   └── tests
│       ├── __init__.py
│       ├── __pycache__
│       │   ├── __init__.cpython-37.pyc
│       │   ├── test_compare_xcom_maps.cpython-37.pyc
│       │   ├── test_compare_xcom_maps.cpython-37-pytest-5.4.3.pyc
│       │   ├── test_dag_validation.cpython-37.pyc
│       │   └── test_dag_validation.cpython-37-pytest-5.4.3.pyc
│       ├── test_compare_xcom_maps.py
│       └── test_dag_validation.py
├── CONTRIBUTING.md
├── dataflow
│   └── java
│       └── wordcount
│           ├── cloudbuild.yaml
│           ├── pom.xml
│           ├── precommit_cloudbuild.yaml
│           ├── src
│           │   ├── main
│           │   │   └── java
│           │   │       └── org
│           │   │           └── apache
│           │   │               └── beam
│           │   │                   └── examples
│           │   │                       └── WordCount.java
│           │   └── test
│           │       └── java
│           │           └── org
│           │               └── apache
│           │                   └── beam
│           │                       └── examples
│           │                           └── WordCountTest.java
│           └── target
│               ├── classes
│               │   └── org
│               │       └── apache
│               │           └── beam
│               │               └── examples
│               │                   ├── WordCount$CountWords.class
│               │                   ├── WordCount$ExtractWordsFn.class
│               │                   ├── WordCount$FormatAsTextFn.class
│               │                   ├── WordCount$WordCountOptions.class
│               │                   └── WordCount.class
│               ├── generated-sources
│               │   └── annotations
│               ├── generated-test-sources
│               │   └── test-annotations
│               ├── maven-archiver
│               │   └── pom.properties
│               ├── maven-status
│               │   └── maven-compiler-plugin
│               │       ├── compile
│               │       │   └── default-compile
│               │       │       ├── createdFiles.lst
│               │       │       └── inputFiles.lst
│               │       └── testCompile
│               │           └── default-testCompile
│               │               ├── createdFiles.lst
│               │               └── inputFiles.lst
│               ├── surefire-reports
│               │   ├── org.apache.beam.examples.WordCountTest-output.txt
│               │   ├── org.apache.beam.examples.WordCountTest.txt
│               │   └── TEST-org.apache.beam.examples.WordCountTest.xml
│               ├── test-classes
│               │   └── org
│               │       └── apache
│               │           └── beam
│               │               └── examples
│               │                   └── WordCountTest.class
│               ├── word-count-beam-0.1.jar
│               └── word-count-beam-bundled-0.1.jar
├── helpers
│   ├── check_format.sh
│   ├── exclusion_list.txt
│   ├── format.sh
│   ├── init_cloudshell.sh
│   ├── init_git_repo.sh
│   ├── run_relevant_cloudbuilds.sh
│   └── run_tests.sh
├── LICENSE
├── license-templates
│   └── LICENSE.txt
├── Makefile
├── precommit_cloudbuild.yaml
├── README.md
├── scripts
│   ├── get_composer_properties.sh
│   └── set_env.sh
└── terraform
    ├── artifacts
    │   ├── backend.tf
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── README.md
    │   ├── terragrunt.hcl
    │   └── variables.tf
    ├── backend.tf
    ├── ci
    │   └── terragrunt.hcl
    ├── datapipelines-infra
    │   ├── backend.tf
    │   ├── composer.tf
    │   ├── gcs.tf
    │   ├── network.tf
    │   ├── outputs.tf
    │   ├── prod.tfvars
    │   ├── README.md
    │   ├── services.tf
    │   ├── terragrunt.hcl
    │   ├── variables.tf
    │   └── versions.tf
    ├── prod
    │   └── terragrunt.hcl
    └── terragrunt.hcl

74 directories, 103 files
```
