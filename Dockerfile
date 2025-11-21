# syntax=docker/dockerfile:1.4
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.6.1-B

# Fix PROJ issue for sf / terra
RUN echo "PROJ_LIB=/opt/conda/share/proj" >> /opt/conda/lib/R/etc/Renviron.site

USER root

# ----------------------------------------------------------------------
# System dependencies needed for common R packages (cached apt)
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      gfortran \
      gcc g++ \
      liblapack-dev libblas-dev libopenblas-dev \
      libcurl4-openssl-dev libxml2-dev libgit2-dev libssl-dev \
      libpng-dev libtiff-dev \
      libfftw3-dev \
      libglu1-mesa-dev libxrender-dev libxtst-dev libxt-dev \
      libxext-dev libxau-dev libxdmcp-dev \
      libmagickcore-dev libmagickwand-dev \
      libgeos-dev libproj-dev libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CC=gcc
ENV CXX=g++
ENV FC=gfortran

# ----------------------------------------------------------------------
# Conda/mamba installs for heavy compiled packages
# ----------------------------------------------------------------------
RUN mamba --version >/dev/null 2>&1 || conda install -y -c conda-forge mamba

RUN mamba install -y -c conda-forge \
      r-sf \
      r-terra \
      r-rcpp r-rcppeigen \
      r-rvcg \
      r-mass \
      r-remotes \
      gdal geos proj fftw \
    && mamba clean -afy

RUN conda clean -y --all || true

# ----------------------------------------------------------------------
# Switch back to notebook user for R package installation
# ----------------------------------------------------------------------
USER $NB_USER

COPY cran-packages.txt /tmp/cran-packages.txt
COPY github-packages.txt /tmp/github-packages.txt
COPY runiverse-packages.txt /tmp/runiverse-packages.txt

# NOTE:
# /opt/conda/lib/R/library      = base R (DO NOT CACHE)
# /opt/conda/lib/R/site-library = user-installed packages (SAFE TO CACHE)

# ----------------------------------------------------------------------
# Bioconductor (EBImage)
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/opt/conda/lib/R/site-library \
    R -e "options(repos='https://cloud.r-project.org'); \
          if (!requireNamespace('BiocManager', quietly=TRUE)) \
              install.packages('BiocManager'); \
          BiocManager::install('EBImage', ask=FALSE, update=FALSE)"

# ----------------------------------------------------------------------
# CRAN package list install
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/opt/conda/lib/R/site-library \
    R -e "pkgs <- scan('/tmp/cran-packages.txt', what=character()); \
          install.packages(pkgs, repos='https://cloud.r-project.org', Ncpus=1); \
          missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
          if (length(missing)) stop('Missing CRAN pkgs: ', paste(missing, collapse=', '))"

# ----------------------------------------------------------------------
# r-universe installs
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/opt/conda/lib/R/site-library \
    R -e \"pkgs <- scan('/tmp/runiverse-packages.txt', what=character()); \
          for (p in pkgs) install.packages( \
              p, \
              repos=c(ropensci='https://ropensci.r-universe.dev', \
                      CRAN='https://cloud.r-project.org') \
          )\"

# ----------------------------------------------------------------------
# GitHub installs
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/opt/conda/lib/R/site-library \
    R -e \"gh <- scan('/tmp/github-packages.txt', what=character()); \
          for (r in gh) { message('installing ', r); \
              remotes::install_github(r, upgrade='never') } \"

# ----------------------------------------------------------------------
# Final load test (non-fatal)
# ----------------------------------------------------------------------
RUN --mount=type=cache,target=/opt/conda/lib/R/site-library \
    R -e \"required <- c('Momocs','polygonoverlap','sf','terra','MASS','Morpho','EBImage'); \
          ok <- sapply(required, require, quietly=TRUE, character.only=TRUE); \
          if (!all(ok)) warning('Missing: ', paste(required[!ok], collapse=', ')) else \
              message('All required packages load correctly.')\"

# Metadata
LABEL maintainer="Ben Marwick <bmarwick@uw.edu>" \
      org.opencontainers.image.description="Dockerfile for ARCHY 488 Lithic Technology Lab" \
      org.opencontainers.image.licenses="Apache-2.0"

USER $NB_USER
