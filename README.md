# kaniko-build-private-repo

Kaniko Builds with Private Repository
Via the Kaniko context, we can git pull Private repositories and build Dockerfile with private git dependencies.
This would be valid for other issues like Python private repository dependency.
Kaniko is a tool to build container images from a Dockerfile, inside a container or Kubernetes cluster.
You can get the motivation for using Kaniko here
When using Kanik you can use mounting of secrets for the SSH or basic auth to git pull or Docker registry.
When you have a Dockerfile using other private dependencies of private Git repo, it would not be sufficient and the build would fail.
This post's motivation was the fact that there is a lot of documentation on Kaniko, but this use case had little to none documentation.

**The Plot**

You have a private repo named dummy-repo-kaniko-build.git, which you would like to build a container from using Kaniko.
The Dockerfile is dependent on other private repo other-private-repo.git.
You will have the Kaniko Pod Definition , defining the flow. 
The Kaniko Pod is using initContainer to create a workspace folder for the Kaniko context.
The Dockerfile
The Dockerfile for such a case would be as follows, while it is cloning the private git repository: other-private-repo.git

(Dockerfile)[https://github.com/yossicohn/kaniko-build-private-repo/blob/main/Dockerfile]
Note the usage of the private repo:  RUN git clone git@github.com:<user>/other-private-repo.git - single-branch
[Dockerfile-no-ssh](https://github.com/yossicohn/kaniko-build-private-repo/blob/main/Dockerfile-no-ssh)

```
ARG BUILDER_HOME_DIR="/home/builder"

# first stage
FROM golang:1.16.3 as go-base
ARG BUILDER_HOME_DIR
# installing git
RUN apt-get update
RUN apt-get install -y git
WORKDIR $BUILDER_HOME_DIR
# cloaning the egit repos in the same shell context
RUN git clone git@github.com:<user>/other-private-repo.git --single-branch
# build the go code
RUN cd other-private-repo && go mod download
RUN cd other-private-repo && GOOS=linux GOARCH=amd64 go build -o "${BUILDER_HOME_DIR}/app-go" .
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

```

**Kaniko Pod **

Note, the definition contains 2 containers:
1. initContainer
2. Kaniko Container
The initContainer prepares the Kaniko workspace with the dummy-repo-kaniko-build.git
The Pod contains mounting for secrets, the git SSH keys, and the Docker registry credentials.

**Create Docker Secret**

```
create secret docker-registry regcred --docker-server=https://index.docker.io/v1/ --docker-username=<user> --docker-password=<password> --docker-email=<user@mail.com>
```

**Create Git SSH Secret
**
We should create a git SSH key, to have the id_rsa and the id_rsa.pub

```
ssh-keygen -m PEM -t rsa -P ""
```

This will result in 2 files: id_rsa, d_rsa.pub
Now the public key id_rsa.pub should be set in the git server configuration 
2. Create the known-hosts

```
ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts_github
```
3. Create the git config

```
Host github.com
  HostName github.com
  AddKeysToAgent yes
  StrictHostKeyChecking no
  ForwardAgent yes
```

3. Create the SSH keys secret from the files

```
kubectl create secret generic ssh-key-secret --from-file=ssh-privatekey=.ssh/id_rsa --from-file=ssh-publickey=.ssh/id_rsa.pub --from-file=known_hosts=known_hosts.github
````
Now the Kubernetes cluster has the needed secrets for mounting in the Pod.

**Pod Definition**
file: kaniko-pod-no-ssh.yaml

```
apiVersion: v1
kind: Pod
metadata:
name: kaniko
spec:
initContainers:
- name: git-clone
image: alpine
command: ["sh", "-c"]
args:
- |
  apk add --no-cache git openssh
  eval `ssh-agent -s`
  mkdir ~/.ssh/
  cp .ssh-src/* ~/.ssh/
  eval `ssh-agent -s`
  ssh-add ~/.ssh/id_rsa
# you can see the log of the ssh command to insure the credentials are valid
  ssh -v git@github.com
  git clone git@github.com:<user>/dummy-repo-kaniko-build.git /workspace
volumeMounts:
- name: docker-volume
mountPath: /workspace
- name: ssh-key-volume
mountPath: ".ssh-src/"
containers:
- name: kaniko
image: gcr.io/kaniko-project/executor:latest
args:
- "--context=dir:///workspace"
- "--destination=<user>/myimage:1.0.0"
volumeMounts:
- name: kaniko-secret
mountPath: /kaniko/.docker/
- name: docker-volume
mountPath: /workspace
restartPolicy: Never
volumes:
- name: kaniko-secret
secret:
secretName: regcred
items:
- key: .dockerconfigjson
path: config.json
- name: ssh-key-volume
secret:
secretName: ssh-key-secret
defaultMode: 0400
- name: docker-volume
emptyDir: {}
- name: ssh-hosts
emptyDir: {}

```

Running the Pod would show failure:
```
kubectl create -f kaniko-pod-no-ssh.yaml
```
The initContainer would finish successfully as the SSH keys are available for the git clone of dummy-repo-kaniko-build.git
But, unfortunately the Kaniko container would fail.
The reason this would not be working, is that the other-private-repo.git is private and the build of the dummy-repo-kaniko-build/Dockerfile would fail on the git clone of the private repo other-private-repo.git
This would occur since the SSH keys are not in the context of the Kaniko build.
The Solution
We should copy the SSH keys to the context (workspace folder)and use them in the Dockerfile while building the container.
In the Kaniko Pod definition, we will add in the InitContainer the copy of the SSH keys:
```
mkdir /workspace/.ssh
cp .ssh-src/* /workspace/.ssh/
```

Fixing the Kaniko Pod for the SSH keys:

[Kaniko Pod](https://github.com/yossicohn/kaniko-build-private-repo/blob/main/kaniko-pod.yaml)

```
apiVersion: v1
kind: Pod
metadata:
name: kaniko
spec:
initContainers:
- name: git-clone
image: alpine
command: ["sh", "-c"]
args:
- |
apk add --no-cache git openssh
eval `ssh-agent -s`
mkdir ~/.ssh/
cp .ssh-src/* ~/.ssh/
eval `ssh-agent -s`
ssh-add ~/.ssh/id_rsa
# you can see the log of the ssh command to insure the credentials are valid
ssh -v git@github.com
git clone git@github.com:<user>/dummy-repo-kaniko-build.git /workspace
mkdir /workspace/.ssh
cp .ssh-src/* /workspace/.ssh/
volumeMounts:
- name: docker-volume
mountPath: /workspace
- name: ssh-key-volume
mountPath: ".ssh-src/"
containers:
- name: kaniko
image: gcr.io/kaniko-project/executor:latest
args:
- "--context=dir:///workspace"
- "--destination=<user>/myimage:1.0.0"
volumeMounts:
- name: kaniko-secret
mountPath: /kaniko/.docker/
- name: docker-volume
mountPath: /workspace
restartPolicy: Never
volumes:
- name: kaniko-secret
secret:
secretName: regcred
items:
- key: .dockerconfigjson
path: config.json
- name: ssh-key-volume
secret:
secretName: ssh-key-secret
defaultMode: 0400
- name: docker-volume
emptyDir: {}
- name: ssh-hosts
emptyDir: {}
```
[Dockerfile](https://github.com/yossicohn/kaniko-build-private-repo/blob/main/Dockerfile)

```
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
# 3. cloaning th egit repos in the same shell context
RUN eval $(ssh-agent -s) && ssh-add /root/.ssh/id_rsa && git clone git@github.com:<user>/other-private-repo.git --single-branch
RUN cd other-private-repo && go mod download
RUN cd other-private-repo && GOOS=linux GOARCH=amd64 go build -o "${BUILDER_HOME_DIR}/app-go" .

# delete the .ssh keys
RUN rm -rf /root/.ssh/

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

```
