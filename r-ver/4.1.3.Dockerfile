ARG IMAGE=debian:bullseye
ARG R_VERSION=4.1.3

FROM registry.gitlab.b-data.ch/r/rsi/${R_VERSION}/${IMAGE} as rsi

FROM ${IMAGE}

LABEL org.opencontainers.image.licenses="GPL-2.0" \
      org.opencontainers.image.source="https://gitlab.b-data.ch/r/docker-stack" \
      org.opencontainers.image.vendor="b-data GmbH" \
      org.opencontainers.image.authors="Olivier Benz <olivier.benz@b-data.ch>"

ARG IMAGE=debian:bullseye
ARG DEBIAN_FRONTEND=noninteractive

ARG BLAS=libopenblas-dev
ARG R_VERSION=4.1.3
ARG BUILD_DATE
ARG CRAN=https://cran.rstudio.com

ENV BASE_IMAGE=${IMAGE} \
    BUILD_DATE=${BUILD_DATE:-2022-04-22} \
    R_VERSION=${R_VERSION} \
    CRAN=${CRAN} \ 
    LANG=en_US.UTF-8 \
    TERM=xterm \
    TZ=Etc/UTC

COPY --from=rsi /usr/local /usr/local

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash-completion \
    build-essential \
    ca-certificates \
    devscripts \
    file \
    fonts-texgyre \
    g++ \
    gfortran \
    gsfonts \
    libbz2-dev \
    '^libcurl[3|4]$' \
    libicu-dev \
    '^libjpeg.*-turbo.*-dev$' \
    liblapack-dev \
    liblzma-dev \
    ${BLAS} \
    libpangocairo-1.0.0 \
    libpaper-utils \
    '^libpcre[2|3]-dev$' \
    libpng-dev \
    libreadline-dev \
    libtiff5 \
    locales \
    pkg-config \
    unzip \
    zip \
    zlib1g \
  ## Switch BLAS/LAPACK (manual mode)
  && if [ ${BLAS} = "libopenblas-dev" ]; then \
    update-alternatives --set libblas.so.3-$(uname -m)-linux-gnu \
      /usr/lib/$(uname -m)-linux-gnu/openblas-pthread/libblas.so.3; \
    update-alternatives --set liblapack.so.3-$(uname -m)-linux-gnu \
      /usr/lib/$(uname -m)-linux-gnu/openblas-pthread/liblapack.so.3; \
  fi \
  ## Update locale
  && sed -i "s/# $LANG/$LANG/g" /etc/locale.gen \
  && locale-gen \
  && update-locale LANG=$LANG \
  ## Add a library directory (for user-installed packages)
  && mkdir -p /usr/local/lib/R/site-library \
  && chown root:staff /usr/local/lib/R/site-library \
  && chmod g+ws /usr/local/lib/R/site-library \
  ## Fix library path
  && echo "R_LIBS_SITE=\${R_LIBS_SITE-'/usr/local/lib/R/site-library'}" >> /usr/local/lib/R/etc/Renviron.site \
  ## Set configured CRAN mirror
  && if [ -z "$BUILD_DATE" ]; then MRAN=$CRAN; \
   else MRAN=https://mran.microsoft.com/snapshot/${BUILD_DATE}; fi \
   && echo MRAN=$MRAN >> /etc/environment \
  && echo "options(repos = c(CRAN='$MRAN'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site \
  ## Use littler installation scripts
  && Rscript -e "install.packages(c('littler', 'docopt'), repos = '$MRAN')" \
  && ln -s /usr/local/lib/R/site-library/littler/examples/install2.r /usr/local/bin/install2.r \
  && ln -s /usr/local/lib/R/site-library/littler/examples/installGithub.r /usr/local/bin/installGithub.r \
  && ln -s /usr/local/lib/R/site-library/littler/bin/r /usr/local/bin/r \
  ## Clean up
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/*

CMD ["R"]
