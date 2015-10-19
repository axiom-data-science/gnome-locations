FROM debian:jessie
MAINTAINER Dave Foster <dave@axds.co>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
    binutils \
    bzip2 \
    ca-certificates \
    cron \
    curl \
    git \
    libglib2.0-0 \
    libkeyutils-dev \
    libproj-dev \
    libsm6 \
    procps \
    pwgen \
    wget

RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-3.10.1-Linux-x86_64.sh && \
    /bin/bash /Miniconda3-3.10.1-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-3.10.1-Linux-x86_64.sh && \
    /opt/conda/bin/conda install --yes conda

ENV PATH /opt/conda/bin:$PATH

RUN conda install -y \
    --channel axiom-data-science \
    --channel ioos \
    netcdf4

RUN mkdir -p /data

WORKDIR /data
COPY update.sh /data/update.sh

CMD ./update.sh

