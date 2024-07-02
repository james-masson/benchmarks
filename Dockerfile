FROM gradle:8-jdk17-focal as builder
ENV BENCHMARKS_PATH /opt/aeron-benchmarks
COPY . /tmp/benchmark-build
WORKDIR /tmp/benchmark-build

RUN --mount=type=cache,target=/root/.gradle \
  --mount=type=cache,target=/home/gradle/.gradle \
  --mount=type=cache,target=/tmp/benchmark-build/.gradle \
  ./gradlew --no-daemon -i clean deployTar

RUN mkdir -p ${BENCHMARKS_PATH} &&\
  tar -C ${BENCHMARKS_PATH} -xf /tmp/benchmark-build/build/distributions/benchmarks.tar

FROM azul/zulu-openjdk:17-latest as runner

RUN apt-get update &&\
  apt-get install -y \
  tar \
  gzip \
  iproute2 \
  bind9-utils \
  bind9-host \
  jq \
  lsb-release \
  python3-pip \
  numactl \
  hwloc &&\
  pip3 install --upgrade --user hdr-plot

ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin
ENV BENCHMARKS_PATH /opt/aeron-benchmarks

COPY --from=builder ${BENCHMARKS_PATH} ${BENCHMARKS_PATH}

WORKDIR ${BENCHMARKS_PATH}/scripts
