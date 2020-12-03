FROM python:3.9-slim-buster
WORKDIR /usr/src/fsst
# Download stable version FlureeDB as a zip file
ADD https://fluree-releases-public.s3.amazonaws.com/fluree-stable.zip /usr/src/
COPY fsst /usr/src/fsst/fsst
RUN apt-get update && \
    apt-get upgrade --yes && \
    apt-get --yes install apt-utils && \
    apt-get install --yes gcc && \
    # Some extra dependencies needed because we use the "slim" python image from docker.
    apt-get --yes install libgmp-dev && \
    apt-get --yes install unzip && \
    mkdir /usr/share/man/man1 && \
    apt-get install dialog -y && \
    # Install Java (dependency for FlureeDB)
    apt-get install openjdk-11-jre-headless -y && \
    # Get the latest pip for the 3.9 version of Python
    python3 -m pip install pip --force && \
    # Dependencies of fsst tool
    python3 -m pip install base58 && \
    python3 -m pip install bitcoinlib && \
    python3 -m pip install aioflureedb && \
    # Unzip the fluree zip file and remove the zip.
    cd /usr/src && \
    unzip fluree-stable.zip -d fsst/ && \
    rm fluree-stable.zip && \
    mv fluree-*/* fsst/ && \
    # Remove stuff we no longer need.
    apt autoremove --yes && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

CMD ["/usr/src/fsst/fluree_start.sh"]

