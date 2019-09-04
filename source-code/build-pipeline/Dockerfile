FROM puckel/docker-airflow:1.10.2

ENV GCLOUD_VERSION=254.0.0

# Install Python2.7 for Google Cloud SDK
USER root
RUN apt-get clean && apt-get update && \
	apt-get install -y --no-install-recommends python2.7 && \
	apt-get clean

RUN pip3 install 'apache-airflow[gcp_api]'

# Switch back to airflow user for running
USER airflow

RUN cd /usr/local/airflow && curl -L0 --silent -o google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz \
  https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz && \
  tar xf google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz && \
  rm google-cloud-sdk-${GCLOUD_VERSION}-linux-x86_64.tar.gz

RUN HOME=/usr/local/airflow /usr/local/airflow/google-cloud-sdk/bin/gcloud components install alpha --quiet
RUN HOME=/usr/local/airflow /usr/local/airflow/google-cloud-sdk/bin/gcloud components install beta --quiet
RUN HOME=/usr/local/airflow /usr/local/airflow/google-cloud-sdk/bin/gcloud components install kubectl --quiet
RUN echo "PATH=$PATH:/usr/local/airflow/google-cloud-sdk/bin" >> /usr/local/airflow/.bashrc

COPY . .
