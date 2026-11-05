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
    gcc-10 g++-10 gfortran libatomic1 \
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
RUN echo 'options(repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"))' \
    >> /opt/conda/lib/R/etc/Rprofile.site

# -------------------------------------------------------------------
# Ensure site-library exists
# -------------------------------------------------------------------
RUN mkdir -p /opt/conda/lib/R/site-library \
    && chown -R $NB_UID:$NB_GID /opt/conda/lib/R/site-library

# -------------------------------------------------------------------
# MAMBA: Core R packages and libraries from conda
# -------------------------------------------------------------------

RUN mamba install -y -c conda-forge -c bioconda \
    r-base=4.4.* proj proj-data gdal geos sqlite fftw \
    r-sf r-terra r-mass r-openmx r-mbess \
    r-broom r-cowplot r-ggbeeswarm r-ggally r-ggcorrplot r-ggrepel \
    r-ggpmisc r-ggtext r-ggridges r-ggmap r-plotrix r-rcolorbrewer \
    r-viridis r-see r-gridgraphics r-here r-readxl r-rio \
    r-factominer r-factoextra r-performance r-fsa r-infer r-psych \
    r-rnaturalearth r-rnaturalearthdata r-maps r-measurements \
    r-ade4 r-aqp r-vegan r-rioja r-rmisc r-hmisc \
    r-plyr r-pbapply r-curl r-pak bioconductor-ebimage \
    r-data.table r-jsonlite r-httr r-geomtextpath \
    r-afex  r-ggforce  r-baseline r-signal \
    r-extradistr r-magic r-linprog r-rcppprogress \
    r-styler r-ggstance r-rgl r-geometry r-rvcg \
    r-doparallel r-colorramps r-bezier r-mclust r-ggtern \
    r-tidyverse r-tidymodels r-magick r-remotes r-lime r-lme4 \
    r-stm r-rtsne r-rsvd r-tidytext r-reshape2 \
    "sysroot_linux-64>=2.28" \
 && mamba clean -afy \
 && conda clean -afy \
 && { find /opt/conda -name "*.pyc" -delete; \
      find /opt/conda -name "__pycache__" -type d -prune -exec rm -rf {} +; \
      true; } 2>/dev/null

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
# GitHub vectors are named by package name because a repo name can
# differ from its package name (achetverikov/apastats is 'apastats2').
RUN Rscript -e "\
    cran <- c('tabula', 'tesselle', 'dimensio', 'tidypaleo', 'Bchron', \
              'geomorph', 'folio', 'isopleuros', 'yyjsonr', 'arkhe', \
              'khroma', 'Morpho', 'ragnar'); \
    gh <- c(Momocs = 'MomX/Momocs'); \
    gh_nodeps <- c(c14bazAAR      = 'ropensci/c14bazAAR', \
                   apastats2      = 'achetverikov/apastats', \
                   polygonoverlap = 'benmarwick/polygonoverlap', \
                   apa            = 'dgromer/apa'); \
    install.packages(cran, Ncpus = parallel::detectCores()); \
    remotes::install_github(unname(gh), upgrade = 'never'); \
    remotes::install_github(unname(gh_nodeps), dependencies = FALSE, \
                            upgrade = 'never'); \
    pkgs <- c(cran, names(gh), names(gh_nodeps), 'lme4'); \
    missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]; \
    if (length(missing)) stop('Failed to install: ', paste(missing, collapse = ', '))"

RUN Rscript -e "\
    options(timeout = 1200); \
    install.packages(c('torch', 'torchvision', 'luz'), \
                     Ncpus = parallel::detectCores()); \
    torch::install_torch()" \
 && Rscript -e "\
    library(torch); print(torch_randn(2, 2)); \
    library(torchvision); library(luz)"

# After all installations, clean up duplicates intelligently
COPY cleanup.R /tmp/cleanup.R
RUN Rscript /tmp/cleanup.R

# Set PROJ vars for the non-root user as well
RUN echo 'PROJ_LIB=/opt/conda/share/proj'  >> /home/$NB_USER/.Renviron \
 && echo 'PROJ_DATA=/opt/conda/share/proj' >> /home/$NB_USER/.Renviron \
 && chown $NB_USER:$NB_GID /home/$NB_USER/.Renviron 2>/dev/null || true

 # -------------------------------------------------------------------
# Install the latest Quarto CLI (includes Deno + Pandoc)
# -------------------------------------------------------------------
RUN set -eux; \
    # Download the latest Quarto .deb URL from GitHub
    QUARTO_DL_URL=$( \
        curl -s https://api.github.com/repos/quarto-dev/quarto-cli/releases/latest \
        | grep -oP '"browser_download_url": "\K[^"]*linux-amd64\.deb' \
        | head -n 1 \
    ); \
    echo "Downloading: $QUARTO_DL_URL"; \
    curl -LO "$QUARTO_DL_URL"; \
    \
    # Install via dpkg, then fix missing deps
    dpkg -i quarto-*.deb || apt-get install -f -y; \
    rm quarto-*.deb; 

# -------------------------------------------------------------------
# Install the latest Typst
# -------------------------------------------------------------------
RUN set -eux; \
    TYPST_DL_URL=$( \
        curl -s https://api.github.com/repos/typst/typst/releases/latest \
        | grep -oP '"browser_download_url": "\K[^"]*x86_64-unknown-linux-musl\.tar\.xz' \
        | head -n 1 \
    ); \
    echo "Downloading: $TYPST_DL_URL"; \
    curl -L "$TYPST_DL_URL" -o typst.tar.xz; \
    tar -xf typst.tar.xz; \
    mv typst-x86_64-unknown-linux-musl/typst /usr/local/bin/typst; \
    chmod +x /usr/local/bin/typst; \
    rm -rf typst.tar.xz typst-x86_64-unknown-linux-musl; \
    typst --version

# -------------------------------------------------------------------
# Install the opencode CLI (AI coding agent)
# OPENCODE_VERSION=latest picks the highest version number among the
# repo's releases. GitHub's own "latest" flag cannot be used because
# the maintainers still publish 1.x releases flagged as latest
# alongside 2.x. Pin a version with --build-arg OPENCODE_VERSION=2.2.5
# The "baseline" build does not require AVX2, so it runs on older
# CPUs as well as newer ones. /usr/local/bin is on every user's PATH,
# including the RStudio Terminal.
# -------------------------------------------------------------------
ARG OPENCODE_VERSION=latest
RUN set -eux; \
    if [ "$OPENCODE_VERSION" = "latest" ]; then \
      OPENCODE_VERSION=$( \
        curl -fsSL ${GITHUB_PAT:+-H "Authorization: Bearer $GITHUB_PAT"} \
          "https://api.github.com/repos/anomalyco/opencode/releases?per_page=100" \
        | grep -oP '"tag_name": "v\K[0-9]+\.[0-9]+\.[0-9]+(?=")' \
        | sort -V | tail -n 1 \
      ); \
    fi; \
    test -n "$OPENCODE_VERSION"; \
    echo "Installing opencode v$OPENCODE_VERSION"; \
    curl -fsSL \
      "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64-baseline.tar.gz" \
      -o /tmp/opencode.tar.gz; \
    tar -xzf /tmp/opencode.tar.gz -C /tmp; \
    install -m 0755 /tmp/opencode /usr/local/bin/opencode; \
    rm -f /tmp/opencode.tar.gz /tmp/opencode; \
    # Run the check with a throwaway HOME: as root with HOME=/home/jovyan,
    # opencode would create root-owned ~/.config, ~/.local and ~/.cache
    # dirs that jovyan then cannot write to.
    HOME=/tmp/opencode-home opencode --version; \
    rm -rf /tmp/opencode-home

# -------------------------------------------------------------------
# Ollama (CPU only) with the embeddinggemma:300m model, for the
# ARCHY 459 module 6 lab. Each student container runs its own server
# on 127.0.0.1:11434; nothing starts it automatically, so run
# `ollama serve` (Terminal) or start it from R when needed.
# The model lives outside /home/jovyan so the home volume cannot hide
# it. GPU libraries are deleted because the hub has no GPUs.
# Pin a different release with --build-arg OLLAMA_VERSION=0.40.13
# -------------------------------------------------------------------
ARG OLLAMA_VERSION=0.40.14
ENV OLLAMA_MODELS=/opt/ollama/models
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends zstd; \
    rm -rf /var/lib/apt/lists/*; \
    curl -fsSL \
      "https://github.com/ollama/ollama/releases/download/v${OLLAMA_VERSION}/ollama-linux-amd64.tar.zst" \
      | tar --zstd -x -C /usr/local; \
    rm -rf /usr/local/lib/ollama/cuda_* \
           /usr/local/lib/ollama/rocm* \
           /usr/local/lib/ollama/vulkan*; \
    mkdir -p "$OLLAMA_MODELS"; \
    # Start a temporary server to pull the model, then stop it.
    # Throwaway HOME so root does not create files in /home/jovyan.
    (HOME=/tmp/ollama-home ollama serve > /tmp/ollama-build.log 2>&1 &); \
    for i in $(seq 1 60); do \
      curl -fs http://127.0.0.1:11434/api/version && break; \
      sleep 1; \
    done; \
    HOME=/tmp/ollama-home ollama pull embeddinggemma:300m; \
    pkill ollama || true; \
    rm -rf /tmp/ollama-home /tmp/ollama-build.log; \
    chmod -R a+rX /opt/ollama; \
    # RStudio sessions may not see Docker ENV values (see the PROJ
    # workaround above), so set OLLAMA_MODELS for R and login shells
    echo 'OLLAMA_MODELS=/opt/ollama/models' >> /opt/conda/lib/R/etc/Renviron.site; \
    echo 'export OLLAMA_MODELS=/opt/ollama/models' > /etc/profile.d/ollama.sh; \
    chmod 644 /etc/profile.d/ollama.sh; \
    ollama --version

# -------------------------------------------------------------------
# Default RStudio preferences for all users
# -------------------------------------------------------------------
COPY rstudio-prefs.json /etc/rstudio/rstudio-prefs.json
RUN chmod 644 /etc/rstudio/rstudio-prefs.json

USER $NB_USER

# check size
RUN du -sh /opt/conda/lib/python*/site-packages 2>/dev/null | sort -h | tail -20
RUN du -sh /opt/conda/lib/*.so* 2>/dev/null | sort -h | tail -20

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
