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
"""Data processing test workflow definition.
"""
import datetime
from airflow import models
from airflow.contrib.operators.dataflow_operator import DataFlowJavaOperator
from airflow.contrib.operators.gcs_download_operator import GoogleCloudStorageDownloadOperator
from compare_xcom_maps import CompareXComMapsOperator

dataflow_staging_bucket = 'gs://%s/staging' % (
    models.Variable.get('dataflow_staging_bucket_test'))

dataflow_jar_location = 'gs://%s/%s' % (
    models.Variable.get('dataflow_jar_location_test'),
    models.Variable.get('dataflow_jar_file_test'))

project = models.Variable.get('gcp_project')
region = models.Variable.get('gcp_region')
zone = models.Variable.get('gcp_zone')
input_bucket = 'gs://' + models.Variable.get('gcs_input_bucket_test')
output_bucket_name = models.Variable.get('gcs_output_bucket_test')
output_bucket = 'gs://' + output_bucket_name
ref_bucket = models.Variable.get('gcs_ref_bucket_test')
output_prefix = 'output'
download_task_prefix = 'download_result'

yesterday = datetime.datetime.combine(
    datetime.datetime.today() - datetime.timedelta(1),
    datetime.datetime.min.time())

default_args = {
    'dataflow_default_options': {
        'project': project,
        'zone': zone,
        'region': region,
        'stagingLocation': dataflow_staging_bucket
    }
}

with models.DAG(
    'test_word_count',
    schedule_interval=None,
    default_args=default_args) as dag:
  dataflow_execution = DataFlowJavaOperator(
      task_id='wordcount-run',
      jar=dataflow_jar_location,
      start_date=yesterday,
      options={
          'autoscalingAlgorithm': 'THROUGHPUT_BASED',
          'maxNumWorkers': '3',
          'inputFile': input_bucket+'/input.txt',
          'output': output_bucket+'/'+output_prefix
      }
  )
  download_expected = GoogleCloudStorageDownloadOperator(
      task_id='download_ref_string',
      bucket=ref_bucket,
      object='ref.txt',
      store_to_xcom_key='ref_str',
      start_date=yesterday
  )
  download_result_one = GoogleCloudStorageDownloadOperator(
      task_id=download_task_prefix+'_1',
      bucket=output_bucket_name,
      object=output_prefix+'-00000-of-00003',
      store_to_xcom_key='res_str_1',
      start_date=yesterday
  )
  download_result_two = GoogleCloudStorageDownloadOperator(
      task_id=download_task_prefix+'_2',
      bucket=output_bucket_name,
      object=output_prefix+'-00001-of-00003',
      store_to_xcom_key='res_str_2',
      start_date=yesterday
  )
  download_result_three = GoogleCloudStorageDownloadOperator(
      task_id=download_task_prefix+'_3',
      bucket=output_bucket_name,
      object=output_prefix+'-00002-of-00003',
      store_to_xcom_key='res_str_3',
      start_date=yesterday
  )
  compare_result = CompareXComMapsOperator(
      task_id='do_comparison',
      ref_task_ids=['download_ref_string'],
      res_task_ids=[download_task_prefix+'_1',
                    download_task_prefix+'_2',
                    download_task_prefix+'_3'],
      start_date=yesterday
  )

  dataflow_execution >> download_result_one
  dataflow_execution >> download_result_two
  dataflow_execution >> download_result_three

  download_expected >> compare_result
  download_result_one >> compare_result
  download_result_two >> compare_result
  download_result_three >> compare_result
