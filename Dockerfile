FROM debian:jessie
MAINTAINER Dave Foster <dave@axds.co>

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install --no-install-recommends -y \
    bzip2 \
    ca-certificates \
    libglib2.0-0 \
    libkeyutils-dev \
    pwgen \
    wget

RUN apt-get update
RUN apt-get upgrade -y

# Setup CONDA (https://hub.docker.com/r/continuumio/miniconda3/~/dockerfile/)
RUN apt-get install -y \
    binutils \
    bzip2 \
    ca-certificates \
    cron \
    curl \
    git \
    libglib2.0-0 \
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

RUN mkdir -p /srv/webgnome/location_files

VOLUME /srv/webgnome/location_files/bering-strait
COPY bering-strait/ /srv/webgnome/location_files/bering-strait/

WORKDIR /srv/webgnome/location_files/
COPY update.sh /srv/webgnome/location_files/

COPY files/crontab /etc/cron.d/gnome-locations
RUN chmod 600 /etc/cron.d/gnome-locations
RUN touch /var/log/crontab.log

CMD cron && tail -f /var/log/crontab.log

