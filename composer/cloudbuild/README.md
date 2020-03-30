# Dags Deployer Application

The Dags Deployer Application seeks to automate the following steps in the DAG deployment process:
1. Identify Dags to Start / Stop based on presence of the dag id in the `running_dags.txt` config file.
1. Check if a DAG needs to be redeployed be checking the filehash of the GCS object against that of the file in the repo.
1. Stop DAGs: 1) Pause the DAG 2) Delete the GCS source file for the DAG 3) Delete the metadata in the airflowdb for the DAG. 
1. Start DAGs: 1) Copy the source file the GCS dags folder 2) Unpause the DAG. 

The process for [how Composer stores code in GCS](https://cloud.google.com/composer/docs/concepts/cloud-storage)
and syncs to the airflow workers / webserver is eventually consistent. Therefore this Dags Deployer Application
retries operations that we might expect to fail (e.g. unpausing a DAG immediately after copying it to GCS may occur
before the scheduler has parsed the DAG, registering it with the airflowdb). This retry process can take minutes so 
golang was selected as the implementation language to leverage goroutines to concurrently perform the 
DAG stop / DAG start processes to speed up deployments involving the starting / stopping of many DAGs.

Cloud Build will build golang application creating an executable with the parameters documented below.

## Parameters
- `repoRoot`: path to the root of this repo 
- `projectID`: GCP project ID
- `composerRegion`: GCP Region wher Composer Environment lives
- `composerEnvName`: Cloud Composer Environment name 
- `dagBucketPrefix`: The GCS dags bucket prefix

### Running the tests
From this directory run
```bash
make test
```

### Deploying a new image
From this directory run
```bash
make push_deploydags_image
```
