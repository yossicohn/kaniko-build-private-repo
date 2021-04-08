ARG HOME_DIR=test-home
ARG SSH_PRIVATE_KEY

FROM golang:1.16.3
ARG SSH_PRIVATE_KEY

RUN apt-get update
RUN apt-get install -y git
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN git clone git@github.com:yossicohn/go-api-skeleton.git --single-branch


FROM python:3.8.5-slim-buster as base

FROM base as builder
ARG HOME_DIR

RUN apt-get -y update && apt-get install -y --no-install-recommends \
  ssh-client pkg-config openssl ssh \
  git-core build-essential libffi-dev procps vim

WORKDIR $HOME_DIR



CMD ["sleep", "1h"]
