# -------------------------------------------------------------------
# Base image
# -------------------------------------------------------------------
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.6.1-B

# Fix PROJ issue
RUN echo "PROJ_LIB=/opt/conda/share/proj" >> /opt/conda/lib/R/etc/Renviron.site

# -------------------------------------------------------------------
# SYSTEM LIBRARIES + COMPILERS
# -------------------------------------------------------------------
USER root

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    gcc-10 g++-10 \
    gfortran \
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
    libmagick++-dev \
    libmagickwand-dev \
    libmagickcore-dev \
    && rm -rf /var/lib/apt/lists/*

# Make gcc/g++ default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
 && update-alternatives --install /
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
