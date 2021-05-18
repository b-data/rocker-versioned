FROM registry.gitlab.b-data.ch/rocker/rstudio:4.0.5

RUN apt-get update -qq && apt-get -y --no-install-recommends install \
  libxml2-dev \
  libcairo2-dev \
  libsqlite-dev \
  libmariadbd-dev \
  libmariadbclient-dev \
  libssh2-1-dev \
  unixodbc-dev \
  libsasl2-dev \
  libtiff-dev \
  libharfbuzz-dev \
  libfribidi-dev \
  libgit2-dev \
  && install2.r --error BiocManager \
  && install2.r --error \
    --deps TRUE \
    tidyverse \
    dplyr \
    devtools \
    formatR \
    remotes \
    selectr \
    caTools \
  ## Clean up
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/*
