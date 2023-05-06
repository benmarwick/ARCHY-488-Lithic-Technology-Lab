 
# pull base image from UW-IT here https://github.com/uw-it-aca/rttl-notebooks/tree/main/rstudio
FROM us-west1-docker.pkg.dev/uwit-mci-axdd/rttl-images/jupyter-rstudio-notebook:2.4.5
 
# install some R packages useful for lithic analysis
# RUN sudo apt-get install libfontconfig1-dev -y
RUN R -e "install.packages(c(
                             'broom', 
                             'cowplot', 
                             'ggbeeswarm', 
                             'here', 
                             'readxl',
                             'ggrepel', 
                             'geomorph', 
                             'Morpho', 
                             'Momocs', 
                             'EBImage',
                             'imager', 
                             'sf', 
                             'tabula', 
                             'tesselle', 
                             'dimensio', 
                             'rio', 
                             'FactoMineR', 
                             'factoextra', 
                             'GGally', 
                             'rnaturalearth',
                             'rnaturalearthdata', 
                             'sf',
                             'rgeos'
                              ), repos='https://cran.rstudio.com')"

# --- Metadata ---
LABEL maintainer = "Ben Marwick <bmarwick@uw.edu>"  \
  org.opencontainers.image.description="Dockerfile for the class ARCHY 488 Lithic Technology Lab" \
  org.opencontainers.image.created="2022-11" \
  org.opencontainers.image.authors="Ben Marwick" \
  org.opencontainers.image.url="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/blob/master/Dockerfile" \
  org.opencontainers.image.documentation="https://github.com/benmarwick/ARCHY-488-Lithic-Technology-Lab/" \
  org.opencontainers.image.licenses="Apache-2.0" \
  org.label-schema.description="Reproducible workflow image (license: Apache 2.0)"
