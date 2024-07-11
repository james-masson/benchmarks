FROM ubuntu:noble AS builder
ARG AERON_VERSION=1.44.1
ENV BENCHMARKS_PATH=/opt/aeron-benchmarks

RUN apt-get update -y &&\
  apt-get install -y \
  openjdk-17-jdk-headless \
  git \
  cmake \
  wget \
  curl \
  unzip \
  build-essential &&\
  wget -q https://services.gradle.org/distributions/gradle-8.8-bin.zip -O /tmp/gradle.zip &&\
  unzip -d /opt /tmp/gradle.zip

ENV PATH=${PATH};/opt/gradle-8.8/bin

COPY . /tmp/benchmark-build
WORKDIR /tmp/benchmark-build

RUN ./cppbuild/cppbuild --aeron-git-tag ${AERON_VERSION} &&\
  cd cppbuild/Release/aeron-prefix/src/aeron &&\
  ./cppbuild/cppbuild --package --no-tests

RUN --mount=type=cache,target=/root/.gradle \
  --mount=type=cache,target=/home/gradle/.gradle \
  --mount=type=cache,target=/tmp/benchmark-build/.gradle \
  ./gradlew --no-daemon -i clean deployTar -Paeron.cdriver.package=cppbuild/Release/aeron-prefix/src/aeron/cppbuild/Release/aeron-${AERON_VERSION}-Linux.tar.gz

RUN mkdir -p ${BENCHMARKS_PATH} &&\
  tar -C ${BENCHMARKS_PATH} -xf /tmp/benchmark-build/build/distributions/benchmarks.tar

FROM ubuntu:noble AS runner

RUN apt-get update &&\
  apt-get install -y \
  tar \
  openjdk-17-jdk-headless \
  gzip \
  iproute2 \
  bind9-utils \
  bind9-host \
  sockperf \
  irqbalance \
  jq \
  lsb-release \
  python3-pip \
  pipx \
  numactl \
  hwloc &&\
  pip install --break-system-packages hdr-plot

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin
ENV BENCHMARKS_PATH=/opt/aeron-benchmarks

COPY --from=builder ${BENCHMARKS_PATH} ${BENCHMARKS_PATH}
# The media driver packaging format does not match what the benchmarks expects
# Manually fix this bit up.
RUN ln -s ${BENCHMARKS_PATH}/bin/aeronmd ${BENCHMARKS_PATH}/scripts/aeron/aeronmd

WORKDIR ${BENCHMARKS_PATH}/scripts
