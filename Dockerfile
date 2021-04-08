ARG HOME_DIR=test-home
ARG SSH_PRIVATE_KEY

FROM golang:1.16.3 as go-base
ARG SSH_PRIVATE_KEY

RUN apt-get update
RUN apt-get install -y git
RUN mkdir /root/.ssh
RUN echo "${SSH_PRIVATE_KEY}" > /root/.ssh/id_rsa
RUN chmod 0400 /root/.ssh/id_rsa
RUN touch /root/.ssh/known_hosts
RUN ssh-keyscan github.com >> /root/.ssh/known_hosts

RUN git clone git@github.com:yossicohn/go-api-skeleton.git --single-branch
RUN cd go-api-skeleton && GOOS=linux GOARCH=amd64  go build -o app-go .



# final stage
FROM alpine:latest

WORKDIR /app

ENV PORT=3000

# Expose port 3000 to the outside world
EXPOSE 3000

COPY --from=go-base /app/app-go /app/

# Command to run the executable
ENTRYPOINT ["/app/app-go"]
