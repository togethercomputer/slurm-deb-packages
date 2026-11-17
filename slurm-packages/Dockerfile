ARG BASE_IMAGE=cr.eu-north1.nebius.cloud/soperator/cuda_base:12.9.0-ubuntu24.04-nccl2.26.5-1-295cb71

FROM $BASE_IMAGE

ARG SLURM_VERSION
ARG LD_LIBRARY_PATH

ARG OPENMPI_VERSION=4.1.7a1
ARG OPENMPI_SUBVERSION=1.2404066
ARG OFED_VERSION=24.04-0.7.0.0

ARG DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt install -y --update \
        git  \
        build-essential \
        devscripts \
        debhelper \
        fakeroot \
        wget \
        curl \
        equivs \
        autoconf \
        pkg-config \
        libssl-dev \
        libpam0g-dev \
        libtool \
        libjansson-dev \
        libjson-c-dev \
        munge \
        libmunge-dev \
        libjwt2 \
        libjwt-dev \
        libhwloc-dev \
        liblz4-dev \
        flex \
        libevent-dev \
        jq \
        squashfs-tools \
        zstd \
        zlib1g \
        zlib1g-dev \
        libpmix-dev


# Download Slurm
RUN cd /usr/src && \
    wget https://download.schedmd.com/slurm/slurm-${SLURM_VERSION}.tar.bz2 && \
    tar -xvf slurm-${SLURM_VERSION}.tar.bz2 && \
    rm -rf slurm-${SLURM_VERSION}.tar.bz2

# Install Openmpi
RUN cd /etc/apt/sources.list.d && \
    wget https://linux.mellanox.com/public/repo/mlnx_ofed/${OFED_VERSION}/ubuntu24.04/mellanox_mlnx_ofed.list && \
    wget -qO - https://www.mellanox.com/downloads/ofed/RPM-GPG-KEY-Mellanox | apt-key add - && \
    apt update && \
    apt install openmpi=${OPENMPI_VERSION}-${OPENMPI_SUBVERSION}

ENV PATH=/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/bin:$PATH

# Vendored debian/rules (pmix path, dh_perl override) and a dh_perl that
# does not use $^X. Under qemu-user $^X is the script itself, so the stock
# helper rewrites shebangs to /usr/bin/dh_perl and then fails on -p/-i.
COPY slurm-packages/dh_perl /usr/bin/dh_perl
COPY slurm-packages/debian/ /tmp/slurm-debian/
ARG DISTRO
RUN chmod 755 /usr/bin/dh_perl && \
    cd /usr/src/slurm-${SLURM_VERSION} && \
    case "${SLURM_VERSION}" in \
      25.05*) cp /tmp/slurm-debian/rules-25.05 debian/rules ;; \
      25.11*) cp /tmp/slurm-debian/rules-25.11 debian/rules ;; \
      *) echo "no vendored debian/rules for ${SLURM_VERSION}" >&2; exit 1 ;; \
    esac && \
    sed -i "1s/([^)]*)/(${SLURM_VERSION}-1+${DISTRO})/" debian/changelog && \
    mk-build-deps -i debian/control -t "apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -y" && \
    debuild -b -uc -us

################################################################
# RESULT
################################################################
# /usr/src/slurm-smd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-client_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-dev_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-doc_25.05.5-1_all.deb
# /usr/src/slurm-smd-libnss-slurm_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libpam-slurm-adopt_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libpmi0_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libpmi2-0_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-libslurm-perl_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-openlava_25.05.5-1_all.deb
# /usr/src/slurm-smd-sackd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmctld_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmdbd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-slurmrestd_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-sview_25.05.5-1_amd64.deb
# /usr/src/slurm-smd-torque_25.05.5-1_all.deb
################################################################

# Move deb files
RUN mkdir /usr/src/debs && \
    mv /usr/src/*.deb /usr/src/debs/
