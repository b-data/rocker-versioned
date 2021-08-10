FROM registry.gitlab.b-data.ch/rocker/tidyverse:4.1.0

ARG CTAN_REPO=${CTAN_REPO:-http://mirror.ctan.org/systems/texlive/tlnet}
ENV CTAN_REPO=${CTAN_REPO}

ENV PATH=/opt/TinyTeX/bin/x86_64-linux:$PATH

## Add LaTeX, rticles and bookdown support
RUN wget "https://travis-bin.yihui.name/texlive-local.deb" \
  && dpkg -i texlive-local.deb \
  && rm texlive-local.deb \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
    cargo \
    curl \
    default-jdk \
    fonts-roboto \
    ghostscript \
    lbzip2 \
    less \
    libbz2-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libicu-dev \
    liblzma-dev \
    libhunspell-dev \
    libmagick++-dev \
    libopenmpi-dev \
    libpcre2-dev \
    libpoppler-cpp-dev \
    # librdf0-dev depends on libcurl4-gnutls-dev
    librdf0-dev \
    libnode-dev \
    libzmq3-dev \
    qpdf \
    ssh \
    texinfo \
    vim \
  ## Install R package redland
  && install2.r --error --skipinstalled redland \
  ## Explicitly install runtime library sub-deps of librdf0-dev
  && apt-get install -y \
	  libcurl4-openssl-dev \
	  libxslt-dev \
	  librdf0 \
	  redland-utils \
	  rasqal-utils \
	  raptor2-utils \
  ## Get rid of librdf0-dev and its dependencies (incl. libcurl4-gnutls-dev)
	&& apt-get -y autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  ## Admin-based install of TinyTeX:
  && wget -qO- "https://yihui.org/tinytex/install-unx.sh" \
    | sh -s - --admin --no-path \
  && mv ~/.TinyTeX /opt/TinyTeX \
  && /opt/TinyTeX/bin/*/tlmgr path add \
  && tlmgr update --self \
  && tlmgr install \
    ae \
    context \
    listings \
    makeindex \
    parskip \
    pdfcrop \
  && tlmgr path add \
  && Rscript -e "tinytex::r_texmf()" \
  && chown -R root:staff /opt/TinyTeX \
  && chmod -R g+w /opt/TinyTeX \
  && chmod -R g+wx /opt/TinyTeX/bin \
  && echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron \
  && install2.r --error PKI \
  ## And some nice R packages for publishing-related stuff
  && install2.r --error --deps TRUE \
    blogdown bookdown rticles rmdshower rJava xaringan \
  ## Clean up
  && rm -rf /tmp/*
