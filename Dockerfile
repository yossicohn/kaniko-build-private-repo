ARG BUILD_HOME_DIR="build-home"
ARG SSH_PRIVATE_KEY

FROM golang:1.16.3 as go-base
ARG SSH_PRIVATE_KEY

RUN apt-get update
RUN apt-get install -y git

RUN mkdir -p /root/.ssh/
COPY .ssh/* /root/.ssh/
RUN chmod 700 /root/.ssh
RUN ls -la  /root/
RUN ls -la  /root/.ssh/
RUN cat /root/.ssh/id_rsa

WORKDIR build-home

RUN echo "PWD" && pwd
RUN eval $(ssh-agent -s) && ssh-add /root/.ssh/id_rsa && git clone git@github.com:yossicohn/go-api-skeleton.git --single-branch
RUN ls -la 
RUN ls -la go-api-skeleton
RUN cd go-api-skeleton && go mod download
RUN cd go-api-skeleton && GOOS=linux GOARCH=amd64 go build -o /root/app-go .
RUN ls -la
RUN rm -rf /root/.ssh/



# final stage
FROM alpine:latest

WORKDIR /app

ENV PORT=3000

# Expose port 3000 to the outside world
EXPOSE 3000

COPY --from=go-base /root/app-go .

# Command to run the executable
ENTRYPOINT ["/app/app-go"]
