ARG HOME_DIR=test-home

FROM python:3.8.5-slim-buster as base

FROM base as builder
ARG HOME_DIR

RUN apt-get -y update && apt-get install -y --no-install-recommends \
  ssh-client pkg-config openssl ssh \
  git-core build-essential libffi-dev procps vim

WORKDIR $HOME_DIR

# RUN git clone git@github.com:yossicohn/go-api-skeleton.git --single-branch

CMD ["sleep", "1h"]
