FROM ubuntu:14.04.3

# Maintainer and description labels
LABEL maintainer="Kapeel Chougule"
LABEL description="This image is used for running Kallisto RNA-seq quantification tool."

# Install required dependencies and Kallisto
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    zlib1g-dev \
    libhdf5-dev \
    git \
    wget \
    nano \
    bash \
    && git clone https://github.com/pachterlab/kallisto.git \
    && cd kallisto \
    && git checkout 5c5ee8a45d6afce65adf4ab18048b40d527fcf5c \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make \
    && make install \
    && cd / \
    && rm -rf /var/lib/apt/lists/* /kallisto

# Set the working directory
WORKDIR /data

# Create necessary directories for RNA data and output
RUN mkdir -p rna_data output transcripts/arch

COPY scripts/main.sh /data/main.sh
COPY scripts/index_transcript.sh /data/index_transcript.sh

ENTRYPOINT ["/data/main.sh"]
