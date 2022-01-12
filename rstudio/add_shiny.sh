#!/usr/bin/with-contenv bash

ADD=${ADD:=none}

SHINY_SERVER_VERSION=${1:-${SHINY_SERVER_VERSION:-latest}}

NCPUS=${NCPUS:--1}

## A script to add shiny to an rstudio-based rocker image.

if [ "$SHINY_SERVER_VERSION" = "latest" ]; then
  SHINY_SERVER_VERSION=$(wget -qO- https://download3.rstudio.org/ubuntu-14.04/x86_64/VERSION)
fi

if [ "$ADD" == "shiny" ]; then
  echo "Adding shiny server to container..."
  apt-get update && apt-get -y install \
    gdebi-core \
    libxt-dev && \
    wget --no-verbose "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-${SHINY_SERVER_VERSION}-amd64.deb" -O ss-latest.deb && \
    gdebi -n ss-latest.deb && \
    rm -f ss-latest.deb && \
    install2.r --error --skipinstalled -n $NCPUS shiny rmarkdown && \
    cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/ && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/downloaded_packages && \
    mkdir -p /var/log/shiny-server && \
    chown shiny.shiny /var/log/shiny-server && \
    mkdir -p /etc/services.d/shiny-server && \
    cd /etc/services.d/shiny-server && \
    echo '#!/bin/bash' > run && echo 'exec shiny-server > /var/log/shiny-server.log' >> run && \
    chmod +x run && \
    adduser rstudio shiny && \
    cd /
fi

if [ $"$ADD" == "none" ]; then
  echo "Nothing additional to add"
fi
