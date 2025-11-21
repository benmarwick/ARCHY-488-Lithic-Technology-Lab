# -------------------------------------------------------------------
# Base image
# -------------------------------------------------------------------
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.6.1-B

# Fix PROJ issue (UW REF0917537)
RUN echo "PROJ_LIB=/opt/conda/share/proj" >> /opt/conda/lib/R/etc/Renviron.site
RUN mamba install -y -c conda-forge r-base=4.3
RUN echo "r-base 4.3.*" >> /opt/conda/conda-meta/pinned

# -------------------------------------------------------------------
# SYSTEM LIBRARIES NEEDED TO BUILD R PACKAGES FROM SOURCE
# -------------------------------------------------------------------
USER root

# Install compilers + system libs required for OpenMx, MBESS, apa, EBImage, sf, terra, Momocs, etc.
RUN apt-get update && apt-get install -y \
    build-essential \
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

# Ensure GCC/G++/Fortran visible as default compilers
ENV CC=gcc
ENV CXX=g++ 
ENV FC=gfortran

# -------------------------------------------------------------------
# MAMBA: install packages available from conda-forge
# -------------------------------------------------------------------
RUN mamba install -y -c conda-forge \
    r-rvcg \
    r-sf \
    r-terra \
    r-mass \
    fftw \
    gdal \
    && mamba clean -afy

# -------------------------------------------------------------------
# Switch back to non-root user
# -------------------------------------------------------------------
USER $NB_USER

RUN R -e "install.packages('BiocManager', repos='https://cran.rstudio.com'); \
          BiocManager::install('EBImage', update=FALSE, ask=FALSE)"
# -------------------------------------------------------------------
# INSTALL CRAN PACKAGES (safe ones; compiled ones now succeed)
# -------------------------------------------------------------------
RUN R -e "pkgs <- c(                         \
                    'broom',                  \
                    'cowplot',                \
                    'ggbeeswarm',             \
                    'GGally',                 \
                    'ggcorrplot',             \
                    'ggrepel',                \
                    'ggpmisc',                \
                    'ggtext',                 \
                    'ggridges',               \
                    'ggmap',                  \
                    'plotrix',                \
                    'RColorBrewer',           \
                    'viridis',                \
                    'see',                    \
                    'gridGraphics',           \
                    'here',                   \
                    'readxl',                 \
                    'rio',                    \
                    'tabula',                 \
                    'tesselle',               \
                    'dimensio',               \
                    'FactoMineR',             \
                    'factoextra',             \
                    'performance',            \
                    'FSA',                    \
                    'infer',                  \
                    'psych',                  \
                    'rnaturalearth',          \
                    'rnaturalearthdata',      \
                    'maps',                   \
                    'measurements',           \
                    'ade4',                   \
                    'aqp',                    \
                    'tidypaleo',              \
                    'vegan',                  \
                    'rioja',                  \
                    'Rmisc',                  \
                    'rcarbon',                \
                    'quarto',                 \
                    'Bchron',                 \
                    'plyr',                   \
                    'pbapply',                \
                    'Morpho',     \
                    'geomorph' \
                    );                        \
          install.packages(pkgs, repos='https://cran.rstudio.com'); \
          if (!all(pkgs %in% rownames(installed.packages()))) {     \
            missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
            stop('Failed to install: ', paste(missing, collapse=', ')); \
          }"

# -------------------------------------------------------------------
# r-universe packages
# -------------------------------------------------------------------
RUN R -e "install.packages('c14bazAAR', repos = c(ropensci = 'https://ropensci.r-universe.dev', CRAN = 'https://cran.rstudio.com'))"

# -------------------------------------------------------------------
# GitHub packages 
# -------------------------------------------------------------------
RUN R -e "remotes::install_github('achetverikov/apastats')" && \
    R -e "if (!require('apastats', quietly=TRUE)) stop('Failed to install apastats')"

RUN R -e "remotes::install_github('dgromer/apa')" && \
    R -e "if (!require('apa', quietly=TRUE)) stop('Failed to install apa')"

RUN R -e "remotes::install_github('MomX/Momocs')" && \
    R -e "if (!require('Momocs', quietly=TRUE)) stop('Failed to install Momocs')"

RUN R -e "remotes::install_github('benmarwick/polygonoverlap')" && \
    R -e "if (!require('polygonoverlap', quietly=TRUE)) stop('Failed to install polygonoverlap')"

# -------------------------------------------------------------------
# Package sanity check
# -------------------------------------------------------------------
RUN R -e "required_pkgs <- c('Momocs', 'polygonoverlap', 'sf', 'terra', 'MASS', 'Morpho', 'EBImage'); \
          installed <- sapply(required_pkgs, require, quietly=TRUE, character.only=TRUE); \
          if (!all(installed)) {                                             \
            missing <- required_pkgs[!installed];                            \
            warning('Some packages failed to load: ', paste(missing, collapse=', ')); \
          } else {                                                           \
            message('All key packages successfully installed and loadable'); \
          }"

# -------------------------------------------------------------------
# Metadata
# -------------------------------------------------------------------
LABEL maintainer="Ben Marwick <bmarwick@uw.edu>" \
      org.opencontainers.image.description="Dockerfile for the class ARCHY 488 Lithic Technology Lab" \
      org.opencontainers.image.created="2022-10" \
      org.opencontainers.image.authors="Ben Marwick" \
      org.opencontainers.image.url="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/blob/master/Dockerfile" \
      org.opencontainers.image.documentation="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.label-schema.description="Reproducible workflow image (license: Apache 2.0)"
