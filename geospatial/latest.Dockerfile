FROM registry.gitlab.b-data.ch/rocker/verse:4.2.0

ARG NCPUS=1

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    gdal-bin \
    libfftw3-dev \
    libgdal-dev \
    libgeos-dev \
    libgsl0-dev \
    libhdf4-alt-dev \
    libhdf5-dev \
    libjq-dev \
    libproj-dev \
    libprotobuf-dev \
    libnetcdf-dev \
    libudunits2-dev \
    netcdf-bin \
    postgis \
    protobuf-compiler \
    sqlite3 \
    tk-dev \
    unixodbc-dev \
  && install2.r --error --skipinstalled -n $NCPUS \
    RColorBrewer \
    RNetCDF \
    classInt \
    deldir \
    gstat \
    hdf5r \
    lidR \
    mapdata \
    maptools \
    mapview \
    ncdf4 \
    proj4 \
    raster \
    rgdal \
    rgeos \
    rlas \
    sf \
    sp \
    spacetime \
    spatstat \
    spatialreg \
    spdep \
    stars \
    terra \
    tidync \
    tmap \
    geosphere \
  ## Archived on 2022-05-04 as check problems were not corrected in time.
  && Rscript -e "devtools::install_version('RandomFields', version = '3.3.14')" \
  ## Archived on 2022-05-04 as requires archived package 'RandomFields'.
  && Rscript -e "devtools::install_version('geoR', version = '1.8-1')" \
  ## from bioconductor
  && R -e "BiocManager::install('rhdf5', update = FALSE, ask = FALSE)" \
  ## Clean up
  && rm -rf /tmp/* \
  && rm -rf /var/lib/apt/lists/*

## Install wgrib2 for NOAA's NOMADS / rNOMADS forecast files
#RUN cd /opt \
#  && wget https://www.ftp.cpc.ncep.noaa.gov/wd51we/wgrib2/wgrib2.tgz \
#  && tar -xvf wgrib2.tgz \
#  && rm -rf wgrib2.tgz \
#  && cd grib2 \
#  && CC=gcc FC=gfortran make \
#  && ln -s /opt/grib2/wgrib2/wgrib2 /usr/local/bin/wgrib2
