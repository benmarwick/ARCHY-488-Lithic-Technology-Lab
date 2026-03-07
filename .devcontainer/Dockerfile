# from https://github.com/espm-157/reproducibility-template
# devcontainer-focused Rocker
FROM ghcr.io/benmarwick/archy-488-lithic-technology-lab:main

RUN useradd -m -s /bin/bash rstudio && \
    echo "rstudio:rstudio" | chpasswd && \
    adduser rstudio sudo

# must be in .devcontainer dir
# RUN R -e 'if(file.exists("install.R")) source("install.R")'
