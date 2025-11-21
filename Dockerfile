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
    libxau-dev libxdmcp-dev \
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
    r-sf r-terra r-mass r-remotes \
    fftw gdal sqlite r-rcpp r-rcppeigen \
    && mamba clean -afy

# -------------------------------------------------------------------
# CRAN packages (Now using Binaries + Parallel)
# -------------------------------------------------------------------
# We grouped OpenMx/MBESS/BiocManager/LargeList here.
# 1. We use Ncpus for parallel installs.
# 2. We use the binary repo set above.
# 3. OpenMx is kept separate if you strictly need the source compilation flags, 
#    otherwise, allow it to install from binary for speed.

# Install OpenMx from source (as requested for flags) & BiocManager
RUN Rscript -e "Sys.setenv(OPENMX_NO_SIMD='1'); \
    Sys.setenv(PKG_CXXFLAGS='-Wno-ignored-attributes'); \
    install.packages(c('OpenMx','MBESS'), type='source', Ncpus=parallel::detectCores())"

RUN Rscript -e "install.packages('BiocManager'); \
    BiocManager::install('EBImage', update=FALSE, ask=FALSE, Ncpus=parallel::detectCores())"

# The Big List - Now fast because of Binaries
RUN Rscript -e "pkgs <- c( \
    'broom','cowplot','ggbeeswarm','GGally','ggcorrplot','ggrepel','ggpmisc','ggtext','ggridges','ggmap', \
    'plotrix','RColorBrewer','viridis','see','gridGraphics','here','readxl','rio','tabula','tesselle', \
    'dimensio','FactoMineR','factoextra','performance','FSA','infer','psych','rnaturalearth', \
    'rnaturalearthdata','maps','measurements','ade4','aqp','tidypaleo','vegan','rioja','Rmisc','rcarbon', \
    'quarto','Bchron','plyr','pbapply','Morpho','geomorph'); \
    install.packages(pkgs, Ncpus=parallel::detectCores()); \
    missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
    if (length(missing)) stop('Failed to install: ', paste(missing, collapse=', '));"

# -------------------------------------------------------------------
# r-universe & GitHub (Use pak for faster dependency resolution)
# -------------------------------------------------------------------
# Installing 'pak' first significantly speeds up github installs
RUN Rscript -e "install.packages('pak', repos = 'https://r-lib.github.io/p/pak/devel/'); \
    pak::pkg_install('ropensci/c14bazAAR'); \
    pak::pkg_install(c('achetverikov/apastats', 'dgromer/apa', 'MomX/Momocs', 'benmarwick/polygonoverlap'));"

# -------------------------------------------------------------------
# Package sanity check
# -------------------------------------------------------------------
RUN R -e "required_pkgs <- c('Momocs','polygonoverlap','sf','terra','MASS','Morpho','EBImage'); \
          installed <- sapply(required_pkgs, require, quietly=TRUE, character.only=TRUE); \
          if (!all(installed)) { missing <- required_pkgs[!installed]; warning('Some packages failed: ', paste(missing, collapse=', ')); } \
          else message('All key packages installed and loadable')"

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
