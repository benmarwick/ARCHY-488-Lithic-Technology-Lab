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

# Make GCC/G++ version 10 default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 100 \
 && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 100 \
 && update-alternatives --set gcc /usr/bin/gcc-10 \
 && update-alternatives --set g++ /usr/bin/g++-10

# CPU flags for Eigen/OpenMx compilation
RUN echo "CXXFLAGS += -O3 -march=core2 -msse2" >> /opt/conda/lib/R/etc/Makeconf

# -------------------------------------------------------------------
# Ensure site-library exists
# -------------------------------------------------------------------
RUN mkdir -p /opt/conda/lib/R/site-library \
    && chown -R $NB_UID:$NB_GID /opt/conda/lib/R/site-library

# -------------------------------------------------------------------
# MAMBA: install R + core packages from conda-forge (sf + GDAL compatible)
# -------------------------------------------------------------------
RUN mamba install -y -c conda-forge \
    r-base=4.4 \
    r-rvcg \
    r-sf \
    r-terra \
    r-mass \
    r-remotes \
    fftw \
    gdal \
    sqlite \
    r-rcpp \
    r-rcppeigen \
    && mamba clean -afy

# -------------------------------------------------------------------
# Install OpenMx + MBESS system-wide
# -------------------------------------------------------------------
RUN Rscript -e "options(repos='https://cloud.r-project.org'); \
    Sys.setenv(OPENMX_NO_SIMD='1'); \
    Sys.setenv(PKG_CXXFLAGS='-Wno-ignored-attributes'); \
    install.packages(c('OpenMx','MBESS'), type='source')"

# -------------------------------------------------------------------
# Bioconductor EBImage system-wide
# -------------------------------------------------------------------
RUN R -e "install.packages('BiocManager', repos='https://cloud.r-project.org'); \
          BiocManager::install('EBImage', update=FALSE, ask=FALSE)"

# -------------------------------------------------------------------
# CRAN packages system-wide
# -------------------------------------------------------------------
RUN R -e "pkgs <- c( \
    'broom','cowplot','ggbeeswarm','GGally','ggcorrplot','ggrepel','ggpmisc','ggtext','ggridges','ggmap', \
    'plotrix','RColorBrewer','viridis','see','gridGraphics','here','readxl','rio','tabula','tesselle', \
    'dimensio','FactoMineR','factoextra','performance','FSA','infer','psych','rnaturalearth', \
    'rnaturalearthdata','maps','measurements','ade4','aqp','tidypaleo','vegan','rioja','Rmisc','rcarbon', \
    'quarto','Bchron','plyr','pbapply','Morpho','geomorph'); \
    install.packages(pkgs, repos='https://cloud.r-project.org'); \
    missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
    if (length(missing)) stop('Failed to install: ', paste(missing, collapse=', '));"

# -------------------------------------------------------------------
# r-universe
# -------------------------------------------------------------------
RUN R -e "install.packages('c14bazAAR', repos=c(ropensci='https://ropensci.r-universe.dev', CRAN='https://cloud.r-project.org'))"

# -------------------------------------------------------------------
# GitHub packages
# -------------------------------------------------------------------
RUN R -e "remotes::install_github('achetverikov/apastats'); \
          remotes::install_github('dgromer/apa'); \
          remotes::install_github('MomX/Momocs'); \
          remotes::install_github('benmarwick/polygonoverlap')"

# -------------------------------------------------------------------
# Package sanity check
# -------------------------------------------------------------------
RUN R -e "required_pkgs <- c('Momocs','polygonoverlap','sf','terra','MASS','Morpho','EBImage'); \
          installed <- sapply(required_pkgs, require, quietly=TRUE, character.only=TRUE); \
          if (!all(installed)) { missing <- required_pkgs[!installed]; warning('Some packages failed: ', paste(missing, collapse=', ')); } \
          else message('All key packages installed and loadable')"

# -------------------------------------------------------------------
# Switch back to notebook user
# -------------------------------------------------------------------
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
