FROM debian:jessie
MAINTAINER Dave Foster <dave@axds.co>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
        binutils \
        bzip2 \
        ca-certificates \
        cron \
        curl \
        file \
        git \
        html-xml-utils \
        libglib2.0-0 \
        libgomp1 \
        libkeyutils-dev \
        libproj-dev \
        libsm6 \
        procps \
        pwgen \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV MINICONDA_VERSION 3.16.0
ENV CONDA_VERSION 3.19.0
RUN echo 'export PATH=/opt/conda/bin:$PATH' > /etc/profile.d/conda.sh && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh && \
    /bin/bash /Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh -b -p /opt/conda && \
    rm Miniconda3-$MINICONDA_VERSION-Linux-x86_64.sh && \
    /opt/conda/bin/conda install --yes conda==$CONDA_VERSION
ENV PATH /opt/conda/bin:$PATH

RUN conda update conda

RUN conda install -y \
    --channel axiom-data-science \
    --channel ioos \
    nco \
    netcdf4

RUN mkdir -p /data

WORKDIR /data
COPY update.sh /data/update.sh

ENTRYPOINT ["./update.sh"]

