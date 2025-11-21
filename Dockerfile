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
    && rm -rf /var/lib/apt/lists/*

# 2. Configure Compilers
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100 \
 && update-alternatives --set gcc /usr/bin/gcc-10 \
 && update-alternatives --set g++ /usr/bin/g++-10

RUN echo "CXXFLAGS += -O3 -march=core2 -msse2" >> /opt/conda/lib/R/etc/Makeconf

# -------------------------------------------------------------------
# SPEED OPTIMIZATION: Use Public Package Manager (Binaries)
# -------------------------------------------------------------------
# This determines the Linux codename (e.g., jammy, focal) and sets the repo
# This prevents compiling from source for 90% of packages.
RUN Rscript -e 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"));' \
    && echo 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"))' >> /opt/conda/lib/R/etc/Rprofile.site

# -------------------------------------------------------------------
# Ensure site-library exists
# -------------------------------------------------------------------
RUN mkdir -p /opt/conda/lib/R/site-library \
    && chown -R $NB_UID:$NB_GID /opt/conda/lib/R/site-library

# -------------------------------------------------------------------
# MAMBA: Core Geospatial
# -------------------------------------------------------------------
# Keeping this is fine as it handles complex GDAL linking
RUN mamba install -y -c conda-forge \
    r-base=4.4 \
    r-sf r-terra r-mass r-remotes  \
    fftw gdal sqlite r-rcpp r-rcppeigen \
    r-broom r-cowplot r-ggbeeswarm r-ggally r-ggcorrplot r-ggrepel \
    r-ggpmisc r-ggtext r-ggridges r-ggmap r-plotrix r-rcolorbrewer \
    r-viridis r-see r-gridgraphics r-here r-readxl r-rio \
    r-factominer r-factoextra r-performance r-fsa r-infer r-psych \
    r-rnaturalearth r-rnaturalearthdata r-maps r-measurements \
    r-ade4 r-aqp r-vegan r-rioja r-rmisc r-quarto \
    r-plyr r-pbapply r-curl r-pak \
    && mamba clean -afy


# -------------------------------------------------------------------
# CRAN packages (Now using Binaries + Parallel)
# -------------------------------------------------------------------
# We grouped BiocManager/LargeList here.
# 1. We use Ncpus for parallel installs.
# 2. We use the binary repo set above.

RUN Rscript -e "install.packages('BiocManager'); \
    BiocManager::install('EBImage', update=FALSE, ask=FALSE, Ncpus=parallel::detectCores())"


# -------------------------------------------------------------------
# Remaining CRAN & GitHub packages (Source installs)
# -------------------------------------------------------------------
RUN Rscript -e "Sys.setenv(OPENMX_NO_SIMD='1'); \
    Sys.setenv(PKG_CXXFLAGS='-Wno-ignored-attributes'); \
    # Install OpenMx and MBESS as binaries via standard R first
    install.packages(c('OpenMx', 'MBESS'))"
    
RUN Rscript -e "Sys.setenv(OPENMX_NO_SIMD='1'); \
    Sys.setenv(PKG_CXXFLAGS='-Wno-ignored-attributes'); \
    # Install the few CRAN packages not on Conda
    pak::pkg_install(c('tabula', 'tesselle', 'dimensio', 'tidypaleo', 'rcarbon', 'Bchron', 'geomorph', 'Morpho'), upgrade = FALSE)" 
    
# Install GitHub packages
RUN Rscript -e "pak::pkg_install(c('ropensci/c14bazAAR', 'achetverikov/apastats', 'dgromer/apa', 'MomX/Momocs', 'benmarwick/polygonoverlap'), upgrade = FALSE);"    


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
