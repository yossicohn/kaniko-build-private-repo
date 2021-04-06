ARG HOME_DIR=test-home
ARG GIT_TOKEN_ARG
FROM python:3.8.5-slim-buster as base

FROM base as builder
ARG HOME_DIR

RUN apt-get -y update && apt-get install -y --no-install-recommends \
  ssh-client pkg-config openssl ssh \
  git-core build-essential libffi-dev procps vim

WORKDIR $HOME_DIR
ENV GIT_TOKEN=$GIT_TOKEN_ARG
ENV ROOT_HOME=/root
COPY /root/.ssh .ssh
RUN mkdir -p -m 600 $ROOT_HOME/.ssh/ && ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
RUN git clone git@github.com:yossicohn/go-api-skeleton.git --single-branch

CMD ["sleep", "1h"]
