# This Dockerfile builds the image used in Cloud Build CI to run 'make test'.

FROM python:buster

# install core tools
RUN apt-get update && apt-get install -y build-essential

RUN curl -sSL https://sdk.cloud.google.com | bash

# install shellcheck
RUN apt-get install shellcheck

# install yapf
RUN pip3 install yapf flake8 pytest

# install golang (+gofmt)
RUN apt-get install -y golang

# Install java + google-java-format jar
RUN apt-get install -y default-jdk maven
RUN wget https://github.com/google/google-java-format/releases/download/google-java-format-1.7/google-java-format-1.7-all-deps.jar --directory-prefix=/usr/share/java/

# install terraform (+fmt )
RUN wget https://releases.hashicorp.com/terraform/0.12.24/terraform_0.12.24_linux_amd64.zip \
  && unzip terraform_0.12.24_linux_amd64.zip \
  && mv terraform /usr/bin \
  && rm terraform_0.12.24_linux_amd64.zip

ENTRYPOINT ["make"]
