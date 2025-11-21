# syntax=docker/dockerfile:1.4
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.6.1-B

# Fix PROJ issue
RUN echo "PROJ_LIB=/opt/conda/share/proj" >> /opt/conda/lib/R/etc/Renviron.site

# Keep R 4.3 from base image (do NOT change r-base)
# Switch to root for system/conda installs
USER root

# --- System libs needed to build common R packages (apt) ---
# cache apt between builds using BuildKit mount
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      build-essential \
      gfortran \
      gcc \
      g++ \
      liblapack-dev \
      libblas-dev \
      libopenblas-dev \
      libcurl4-openssl-dev \
      libxml2-dev \
      libgit2-dev \
      libssl-dev \
      libpng-dev \
      libtiff-dev \
      libfftw3-dev \
      libglu1-mesa-dev \
      libxrender-dev \
      libxtst-dev \
      libxt-dev \
      libxext-dev \
      libxau-dev \
      libxdmcp-dev \
      libmagickcore-dev \
      libmagickwand-dev \
      libgeos-dev \
      libproj-dev \
      libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Ensure compilers used by R builds (use system defaults)
ENV CC=gcc
ENV CXX=g++
ENV FC=gfortran

# --- Mamba/conda installs: heavy prebuilt binaries (conda-forge) ---
# install mamba if not present (base image often has mamba)
RUN mamba --version >/dev/null 2>&1 || conda install -y -c conda-forge mamba

# Install binary R packages and system libs from conda-forge
# Keep this layer small and cacheable
RUN mamba install -y -c conda-forge \
      r-sf \
      r-terra \
      r-rcppeigen \
      r-rcpp \
      r-rvcg \
      r-mass \
      r-remotes \
      gdal \
      geos \
      proj \
      fftw \
      && mamba clean -afy

# Clean conda caches (helps image size)
RUN conda clean -y --all || true

# Switch back to notebook (non-root) user for CRAN/Bioconductor installs
USER $NB_USER

# Use BuildKit cache for R library to avoid re-compiling all packages
# Copy package lists into image (these files are described below)
COPY cran-packages.txt /tmp/cran-packages.txt
COPY github-packages.txt /tmp/github-packages.txt
COPY runiverse-packages.txt /tmp/runiverse-packages.txt

# Install Bioconductor EBImage via BiocManager (binary will be used if available)
# Use --mount=type=cache for R library to cache compiled packages between builds
RUN --mount=type=cache,target=/opt/conda/lib/R/library \
    R -e "options(repos='https://cloud.r-project.org'); \
          if (!requireNamespace('BiocManager', quietly=TRUE)) install.packages('BiocManager'); \
          BiocManager::install('EBImage', update=FALSE, ask=FALSE)"

# Install CRAN packages from list (Ncpus=1 to reduce OOM on small runners)
RUN --mount=type=cache,target=/opt/conda/lib/R/library \
    R -e "pkgs <- scan('/tmp/cran-packages.txt', what=character()); \
          install.packages(pkgs, repos='https://cloud.r-project.org', Ncpus=1); \
          missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
          if (length(missing)) { stop('Missing CRAN pkgs: ', paste(missing, collapse=', ')) }"

# Install r-universe packages
RUN --mount=type=cache,target=/opt/conda/lib/R/library \
    R -e "pkgs <- scan('/tmp/runiverse-packages.txt', what=character()); \
          for (p in pkgs) install.packages(p, repos=c(ropensci='https://ropensci.r-universe.dev', CRAN='https://cloud.r-project.org'))"

# Install GitHub packages listed (each in single loop so cache is maximized)
RUN --mount=type=cache,target=/opt/conda/lib/R/library \
    R -e "gh <- scan('/tmp/github-packages.txt', what=character()); \
          for (r in gh) { message('installing ', r); remotes::install_github(r, upgrade='never') }"

# Final sanity check for key packages (non-fatal)
RUN --mount=type=cache,target=/opt/conda/lib/R/library \
    R -e "required_pkgs <- c('Momocs','polygonoverlap','sf','terra','MASS','Morpho','EBImage'); \
          installed <- sapply(required_pkgs, require, quietly=TRUE, character.only=TRUE); \
          if (!all(installed)) { missing <- required_pkgs[!installed]; warning('Some packages failed to load: ', paste(missing, collapse=', ')) } else message('All key packages loadable')"

# Metadata
LABEL maintainer="Ben Marwick <bmarwick@uw.edu>" \
      org.opencontainers.image.description="Dockerfile for ARCHY 488 Lithic Technology Lab" \
      org.opencontainers.image.licenses="Apache-2.0"

# Keep NB_USER as final user
USER $NB_USER
