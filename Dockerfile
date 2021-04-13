ARG BUILDER_HOME_DIR="/home/builder"

FROM golang:1.16.3 as go-base
ARG BUILDER_HOME_DIR

# installing git
RUN apt-get update
RUN apt-get install -y git

# copying the ssh keys  to/root/.ssh
RUN mkdir -p /root/.ssh/
COPY .ssh/* /root/.ssh/

WORKDIR $BUILDER_HOME_DIR

# 1. restarting the ssh agent
# 2. adding the private key to the agent
# 3. cloaning the git repos in the same shell context
RUN eval $(ssh-agent -s) && ssh-add /root/.ssh/id_rsa && git clone git@github.com:<user>/other-private-repo.git --single-branch
RUN cd go-api-skeleton && go mod download
RUN cd go-api-skeleton && GOOS=linux GOARCH=amd64 go build -o "${BUILDER_HOME_DIR}/app-go" .


# final stage
FROM alpine:latest
ARG BUILDER_HOME_DIR
WORKDIR /app

ENV PORT=3000

# Expose port 3000 to the outside world
EXPOSE 3000

COPY --from=go-base "${BUILDER_HOME_DIR}/app-go" .

# Command to run the executable
ENTRYPOINT ["/app/app-go"]
