# pull base image from UW-IT here https://github.com/uw-it-aca/rttl-notebooks/tree/main/rstudio
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.6.1-B

# deal with an issue UW REF0917537
RUN echo "PROJ_LIB=/opt/conda/share/proj" >> /opt/conda/lib/R/etc/Renviron.site

# Install system dependencies for spatial packages
# Switch to root to install system dependencies ---
USER root

# Install system dependencies
# Added libgl1-mesa-glx (often needed for spatial plotting)
RUN apt-get update && apt-get install -y \
    libudunits2-dev \
    libgl1-mesa-glx \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Installing terra/sf from source fails due to GLIBC mismatch. 
# We install binaries from conda-forge instead.
RUN conda install -y -c conda-forge \
    r-sf \
    r-terra \
    r-spatstat \
    r-raster \
    r-udunits2 \
    gdal \
    geos \
    proj \
    udunits2 \
    && conda clean -afy

# Switch back to notebook user if needed
USER $NB_USER

# Install devtools and remotes first
RUN R -e "install.packages(c('devtools', 'remotes'), repos='https://cran.rstudio.com')"

# Install CRAN packages with error checking
RUN R -e "pkgs <- c(                         \
                    # data manipulation      \
                    'MASS',                   \
                    'broom',                  \
                    # plotting               \
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
                    # file handling          \
                    'here',                   \
                    'readxl',                 \
                    'rio',                    \
                    # shape                  \
                    'geomorph',               \
                    'Morpho',                 \
                    # images                 \
                    'EBImage',                \
                    'imager',                 \
                    # stats                  \
                    'tabula',                 \
                    'tesselle',               \
                    'dimensio',               \
                    'FactoMineR',             \
                    'factoextra',             \
                    'performance',            \
                    'FSA',                    \
                    'infer',                  \
                    'psych',                  \
                    # mapping and GIS        \
                    'rnaturalearth',          \
                    'rnaturalearthdata',      \   
                    'maps',                   \
                    'measurements',           \
                    # palaeoecology          \
                    'ade4',                   \
                    'aqp',                    \
                    'tidypaleo',              \
                    'vegan',                  \
                    'rioja',                  \
                    # misc                   \
                    'Rmisc',                  \
                    'rcarbon',                \
                    'quarto',                 \
                    'Bchron',                 \
                    'plyr',                   \
                    'pbapply'                 \
                    );                        \
          install.packages(pkgs, repos='https://cran.rstudio.com'); \
          if (!all(pkgs %in% rownames(installed.packages()))) {     \
            missing <- pkgs[!pkgs %in% rownames(installed.packages())]; \
            stop('Failed to install: ', paste(missing, collapse=', ')); \
          }"

# Install r-universe packages
RUN R -e "install.packages('c14bazAAR', repos = c(ropensci = 'https://ropensci.r-universe.dev', CRAN = 'https://cran.rstudio.com'))"

# Install GitHub packages individually with error checking
RUN R -e "remotes::install_github('achetverikov/apastats')" && \
    R -e "if (!require('apastats', quietly=TRUE)) stop('Failed to install apastats')"

RUN R -e "remotes::install_github('dgromer/apa')" && \
    R -e "if (!require('apa', quietly=TRUE)) stop('Failed to install apa')"

RUN R -e "remotes::install_github('MomX/Momocs')" && \
    R -e "if (!require('Momocs', quietly=TRUE)) stop('Failed to install Momocs')"

RUN R -e "remotes::install_github('benmarwick/polygonoverlap')" && \
    R -e "if (!require('polygonoverlap', quietly=TRUE)) stop('Failed to install polygonoverlap')"

# Verify key packages are installed
RUN R -e "required_pkgs <- c('Momocs', 'polygonoverlap', 'sf', 'terra'); \
          installed <- sapply(required_pkgs, require, quietly=TRUE, character.only=TRUE); \
          if (!all(installed)) {                                             \
            missing <- required_pkgs[!installed];                            \
            warning('Some packages failed to load: ', paste(missing, collapse=', ')); \
          } else {                                                           \
            message('All key packages successfully installed and loadable'); \
          }"

# --- Metadata ---
LABEL maintainer="Ben Marwick <bmarwick@uw.edu>" \
      org.opencontainers.image.description="Dockerfile for the class ARCHY 488 Lithic Technology Lab" \
      org.opencontainers.image.created="2022-10" \
      org.opencontainers.image.authors="Ben Marwick" \
      org.opencontainers.image.url="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/blob/master/Dockerfile" \
      org.opencontainers.image.documentation="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.label-schema.description="Reproducible workflow image (license: Apache 2.0)"
