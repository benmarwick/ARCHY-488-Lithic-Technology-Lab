# -------------------------------------------------------------------
# Base image
# -------------------------------------------------------------------
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.6.1-B

# Fix PROJ issue & Set Env Vars globally
ENV PROJ_LIB=/opt/conda/share/proj \
    OPENMX_NO_SIMD=1 \
    PKG_CXXFLAGS='-Wno-ignored-attributes -w'  \
    PIP_NO_CACHE_DIR=1 \
    PROJ_DATA=/opt/conda/share/proj \
    PROJ_NETWORK=ON

ARG GITHUB_PAT
ENV GITHUB_PAT=$GITHUB_PAT

ENV LD_LIBRARY_PATH=/opt/conda/lib
ENV PKG_CONFIG_PATH=/opt/conda/lib/pkgconfig

# -------------------------------------------------------------------
# SYSTEM LIBRARIES + COMPILERS
# -------------------------------------------------------------------

USER root

RUN conda config --system --set channel_priority strict

# 1. Install system libs (Keep this, it's efficient)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    gcc-10 g++-10 gfortran \
    liblapack-dev libblas-dev libopenblas-dev \
    libcurl4-openssl-dev libxml2-dev libgit2-dev libssl-dev \
    libpng-dev libtiff-dev libfftw3-dev \
    libglu1-mesa-dev libxrender-dev libxtst-dev libxt-dev libxext-dev \
    libxau-dev libxdmcp-dev libeigen3-dev \
    libmagick++-dev libmagickwand-dev libmagickcore-dev \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/proj

# 2. Configure Compilers
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100 \
 && update-alternatives --set gcc /usr/bin/gcc-10 \
 && update-alternatives --set g++ /usr/bin/g++-10

RUN echo "CXXFLAGS += -O3 -march=core2 -msse2" >> /opt/conda/lib/R/etc/Makeconf

# R REPO CONFIGURATION (Binaries)
# -------------------------------------------------------------------
# 1. Posit Package Manager (CRAN Binaries)
# 2. r-universe (GitHub Binaries for Momocs and ropensci)
RUN Rscript -e 'options(repos = c( \
    CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest", \
    ropensci = "https://ropensci.r-universe.dev", \
    momx = "https://momx.r-universe.dev"));' \
    && echo 'options(repos = c( \
    CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest", \
    ropensci = "https://ropensci.r-universe.dev", \
    momx = "https://momx.r-universe.dev"))' >> /opt/conda/lib/R/etc/Rprofile.site

# -------------------------------------------------------------------
# Ensure site-library exists
# -------------------------------------------------------------------
RUN mkdir -p /opt/conda/lib/R/site-library \
    && chown -R $NB_UID:$NB_GID /opt/conda/lib/R/site-library

# -------------------------------------------------------------------
# MAMBA: Core R packages and libraries from conda
# -------------------------------------------------------------------

RUN mamba install -y -c conda-forge \
    r-base=4.4.* proj proj-data gdal geos sqlite fftw \
 && mamba clean -afy 

RUN mamba install -y -c conda-forge -c bioconda \
    r-sf r-terra r-mass r-openmx r-mbess \
    r-broom r-cowplot r-ggbeeswarm r-ggally r-ggcorrplot r-ggrepel \
    r-ggpmisc r-ggtext r-ggridges r-ggmap r-plotrix r-rcolorbrewer \
    r-viridis r-see r-gridgraphics r-here r-readxl r-rio \
    r-factominer r-factoextra r-performance r-fsa r-infer r-psych \
    r-rnaturalearth r-rnaturalearthdata r-maps r-measurements \
    r-ade4 r-aqp r-vegan r-rioja r-rmisc r-quarto \
    r-plyr r-pbapply r-curl r-pak bioconductor-ebimage \
    r-data.table r-jsonlite r-httr \
    r-afex  r-ggforce \
    r-extradistr r-magic r-linprog r-rcppprogress \
    r-styler r-ggstance r-rgl r-geometry r-rvcg \
    r-doparallel r-colorramps r-bezier r-mclust \
 && mamba clean -y  -t && rm -rf /opt/conda/pkgs/*

 # NOW set the environment variables after PROJ is installed
RUN echo 'PROJ_LIB=/opt/conda/share/proj'  >> /opt/conda/lib/R/etc/Renviron \
 && echo 'PROJ_DATA=/opt/conda/share/proj' >> /opt/conda/lib/R/etc/Renviron \
 && echo 'PROJ_LIB=/opt/conda/share/proj'  >> /opt/conda/lib/R/etc/Renviron.site \
 && echo 'PROJ_DATA=/opt/conda/share/proj' >> /opt/conda/lib/R/etc/Renviron.site \
 && echo 'Sys.setenv(PROJ_LIB="/opt/conda/share/proj")' >> /opt/conda/lib/R/etc/Rprofile.site \
 && echo 'Sys.setenv(PROJ_DATA="/opt/conda/share/proj")' >> /opt/conda/lib/R/etc/Rprofile.site \
 && echo 'options(expressions = 500000)' >> /opt/conda/lib/R/etc/Rprofile.site \
 && chmod 644 /opt/conda/share/proj/proj.db

 RUN echo '.First <- function() { \
  Sys.setenv(PROJ_LIB="/opt/conda/share/proj"); \
  Sys.setenv(PROJ_DATA="/opt/conda/share/proj"); \
}' >> /opt/conda/lib/R/etc/Rprofile.site

# -------------------------------------------------------------------
# Remaining CRAN & GitHub packages (Source installs)
# -------------------------------------------------------------------

# Install CRAN and GitHub packages
RUN Rscript -e "\
    install.packages(c( \
        'tabula', 'tesselle', 'dimensio', 'tidypaleo', 'Bchron', 'geomorph', \
        'Momocs', 'folio', 'isopleuros', 'yyjsonr', 'arkhe', 'khroma', 'Morpho' \
    ), quiet = TRUE, Ncpus = parallel::detectCores()); \
    Sys.setenv(PKG_SYSREQS='false'); \
    options(pak.num_workers = 1); \
    pak::pkg_install(c( \
        'ropensci/c14bazAAR', \
        'achetverikov/apastats', \
        'benmarwick/polygonoverlap', \
        'dgromer/apa'), dependencies = FALSE)" \
    1> /dev/null

# After all installations, clean up duplicates intelligently
COPY cleanup.R /tmp/cleanup.R
RUN Rscript /tmp/cleanup.R

# Set PROJ vars for the non-root user as well
RUN echo 'PROJ_LIB=/opt/conda/share/proj'  >> /home/$NB_USER/.Renviron \
 && echo 'PROJ_DATA=/opt/conda/share/proj' >> /home/$NB_USER/.Renviron \
 && chown $NB_USER:$NB_GID /home/$NB_USER/.Renviron 2>/dev/null || true

USER $NB_USER

# -------------------------------------------------------------------
# Metadata
# -------------------------------------------------------------------
LABEL maintainer="Ben Marwick <bmarwick@uw.edu>" \
      org.opencontainers.image.description="Dockerfile for ARCHY 488 Lithic Technology Lab" \
      org.opencontainers.image.created="2022-10" \
      org.opencontainers.image.authors="Ben Marwick" \
      org.opencontainers.image.url="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/blob/master/Dockerfile" \
      org.opencontainers.image.documentation="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.label-schema.description="Reproducible workflow image (license: Apache 2.0)"
