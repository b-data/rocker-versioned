ARG IMAGE=debian:bullseye
ARG GIT_VERSION=2.35.1

FROM registry.gitlab.b-data.ch/git/gsi/${GIT_VERSION}/${IMAGE} as gsi

FROM registry.gitlab.b-data.ch/r/r-ver:4.1.2

ARG DEBIAN_FRONTEND=noninteractive

ARG GIT_VERSION=2.35.1
ARG PANDOC_TEMPLATES_VERSION=2.14.1
ARG RSTUDIO_VERSION=2021.09.2+382
ARG S6_VERSION=v2.2.0.3

ENV GIT_VERSION=${GIT_VERSION} \
    PANDOC_TEMPLATES_VERSION=${PANDOC_TEMPLATES_VERSION} \
    RSTUDIO_VERSION=${RSTUDIO_VERSION} \
    S6_VERSION=${S6_VERSION} \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    PATH=/usr/lib/rstudio-server/bin:$PATH

COPY --from=gsi /usr/local /usr/local
COPY --from=gsi /etc/bash_completion.d /etc/bash_completion.d

## Download and install RStudio server & dependencies
## Attempts to get detect latest version, otherwise falls back to version given in $VER
## Symlink pandoc, pandoc-citeproc so they are available system-wide
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    curl \
    file \
    libapparmor1 \
    libclang-dev \
    libcurl4-openssl-dev \
    libedit2 \
    libpq-dev \
    libssl-dev \
    lsb-release \
    nano \
    psmisc \
    procps \
    python-setuptools \
    sudo \
    wget \
    ## Additional git runtime dependencies
    libcurl3-gnutls \
    liberror-perl \
    ## Additional git runtime recommendations
    less \
    ssh-client \
  && if [ -z "$RSTUDIO_VERSION" ]; \
    then wget "https://www.rstudio.org/download/latest/stable/server/bionic/rstudio-server-latest-amd64.deb"; \
    else /bin/bash -c 'wget "http://download2.rstudio.org/server/bionic/amd64/rstudio-server-${RSTUDIO_VERSION/'+'/'-'}-amd64.deb"'; fi \
  && dpkg -i rstudio-server-*-amd64.deb \
  && rm rstudio-server-*-amd64.deb \
  ## https://github.com/rocker-org/rocker-versioned2/issues/137
  rm -f /var/lib/rstudio-server/secure-cookie-key \
  ## Symlink pandoc & standard pandoc templates for use system-wide
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin \
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin \
  && git clone --recursive --branch ${PANDOC_TEMPLATES_VERSION} https://github.com/jgm/pandoc-templates \
  && rm -rf /opt/pandoc/templates \
  && mkdir -p /opt/pandoc/templates \
  && cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates* \
  && rm -rf /root/.pandoc \
  && mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates \
  ## RStudio wants an /etc/R, will populate from $R_HOME/etc
  && mkdir -p /etc/R \
  && echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron.site \
  ## Need to configure non-root user for RStudio
  && useradd rstudio \
  && echo "rstudio:rstudio" | chpasswd \
	&& mkdir /home/rstudio \
	&& chown rstudio:rstudio /home/rstudio \
	&& addgroup rstudio staff \
  ## Prevent rstudio from deciding to use /usr/bin/R if a user apt-get installs a package
  && echo 'rsession-which-r=/usr/local/bin/R' >> /etc/rstudio/rserver.conf \
  ## use more robust file locking to avoid errors when using shared volumes:
  && echo 'lock-type=advisory' >> /etc/rstudio/file-locks \
  ## Set default branch name to main
  && git config --system init.defaultBranch main \
  ## Store passwords for one hour in memory
  && git config --system credential.helper "cache --timeout=3600" \
  ## Merge the default branch from the default remote when "git pull" is run
  && git config --system pull.rebase false \
  # Push the current branch with the same name on the remote
  && git config --system push.default simple \
  ## Set up S6 init system
  && wget -P /tmp/ https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-amd64.tar.gz \
  ## need the modified double tar now, see https://github.com/just-containers/s6-overlay/issues/288
  && tar hzxf /tmp/s6-overlay-amd64.tar.gz -C / --exclude=usr/bin/execlineb \
  && tar hzxf /tmp/s6-overlay-amd64.tar.gz -C /usr ./bin/execlineb && $_clean \
  ## Set up RStudio init scripts
  && mkdir -p /etc/services.d/rstudio \
  && echo '#!/usr/bin/with-contenv bash \
          \n## load /etc/environment vars first: \
  		    \nfor line in $( cat /etc/environment ) ; do export $line > /dev/null; done \
          \nexec /usr/lib/rstudio-server/bin/rserver --server-daemonize 0' \
          > /etc/services.d/rstudio/run \
  && echo '#!/bin/bash \
          \nrstudio-server stop' \
          > /etc/services.d/rstudio/finish \
  ## Log to syslog
  && echo '[*] \
          \nlog-level=warn \
          \nlogger-type=syslog' \
          > /etc/rstudio/logging.conf \
  ## Rocker's default RStudio settings, for better reproducibility
  && mkdir -p /home/rstudio/.rstudio/monitored/user-settings \
  && echo 'alwaysSaveHistory="0" \
          \nloadRData="0" \
          \nsaveAction="0"' \
          > /home/rstudio/.rstudio/monitored/user-settings/user-settings \
  && chown -R rstudio:rstudio /home/rstudio/.rstudio \
  ## Clean up
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/*

COPY userconf.sh /etc/cont-init.d/userconf

## running with "-e ADD=shiny" adds shiny server
COPY add_shiny.sh /etc/cont-init.d/add
COPY disable_auth_rserver.conf /etc/rstudio/disable_auth_rserver.conf
COPY pam-helper.sh /usr/lib/rstudio-server/bin/pam-helper

EXPOSE 8787

CMD ["/init"]
