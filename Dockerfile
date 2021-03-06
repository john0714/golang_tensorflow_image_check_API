# we use tensorflow official docker image
FROM tensorflow/tensorflow

# Install TensorFLow C library
RUN curl -L \
	"https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-1.15.0.tar.gz" | \
	tar -C "/usr/local" -xz
	
# Reset sharing library cache
RUN ldconfig

# Hide some warning
ENV TF_CPP_MIN_LOG_LEVEL 2

# install golang in docker - from docker golang official image
RUN apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
    wget \
    git \
	&& rm -rf /var/lib/apt/lists/*

ENV GOLANG_VERSION 1.13.8

RUN set -eux; \
	\
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64) goRelArch='linux-amd64'; goRelSha256='0567734d558aef19112f2b2873caa0c600f1b4a5827930eb5a7f35235219e9d8' ;; \
		armhf) goRelArch='linux-armv6l'; goRelSha256='75f590d8e048a97cbf8b09837b15b3e6b44e1374718a96a5c3a994843ef44a4d' ;; \
		arm64) goRelArch='linux-arm64'; goRelSha256='b46c0235054d0eb69a295a2634aec8a11c7ae19b3dc53556a626b89dc1f8cdb0' ;; \
		i386) goRelArch='linux-386'; goRelSha256='2305c1c46b3eaf574c7b03cfa6b167c199a2b52da85872317438c90074fdb46e' ;; \
		ppc64el) goRelArch='linux-ppc64le'; goRelSha256='4c987b3969d33a93880a218064d2330d7f55c9b58698e78db6b56012058e91a9' ;; \
		s390x) goRelArch='linux-s390x'; goRelSha256='994f961df0d7bdbfa6f7eed604539acf9159444dabdff3ce8e938d095d85f756' ;; \
		*) goRelArch='src'; goRelSha256='b13bf04633d4d8cf53226ebeaace8d4d2fd07ae6fa676d0844a688339debec34'; \
			echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; echo >&2 ;; \
	esac; \
	\
	url="https://golang.org/dl/go${GOLANG_VERSION}.${goRelArch}.tar.gz"; \
	wget -O go.tgz "$url"; \
	echo "${goRelSha256} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ "$goRelArch" = 'src' ]; then \
		echo >&2; \
		echo >&2 'error: UNIMPLEMENTED'; \
		echo >&2 'TODO install golang-any from jessie-backports for GOROOT_BOOTSTRAP (and uninstall after build)'; \
		echo >&2; \
		exit 1; \
	fi; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" "$GOPATH/pkg" && chmod -R 777 "$GOPATH"
WORKDIR "/go/src/app"

# Tensorflow not support go.mod yet(2020-03-22)
# ENV GO111MODULE="on"
# RUN go mod init 

# install go packages in docker - core_protos_go_proto error...
RUN go get github.com/tensorflow/tensorflow/tensorflow/go \
  github.com/tensorflow/tensorflow/tensorflow/go/op \
  github.com/julienschmidt/httprouter
  
# download Inception model in /model directory
RUN apt-get update && apt-get install -y unzip zip
RUN mkdir -p /model && \
  wget "https://storage.googleapis.com/download.tensorflow.org/models/inception5h.zip" -O /model/inception.zip && \
  unzip /model/inception.zip -d /model && \
  chmod -R 777 /model

# Create account for using API
RUN adduser --disabled-password --gecos '' api
USER api

# Change directory
WORKDIR "/go/src/app"

# Copy file and directory from host to image(container already have that from volume option)
COPY . .

RUN go env
WORKDIR "/go/pkg/mod"
RUN ls -al

WORKDIR "/go/src/app"

# compile and run code(-v : print the names of packages as they are compiled)
RUN go install -v ./...

# set work command when docker container start(not when docker image build)
CMD [ "app" ]