# syntax=docker/dockerfile:1.7.0

# Set full semantic version of the base image with variant tag
FROM python:3.12.7-slim-bookworm AS build

# https://github.com/jupyter/docker-stacks/blob/main/images/docker-stacks-foundation/Dockerfile

# Avoid warnings by switching to noninteractive
# https://serverfault.com/questions/618994/when-building-from-dockerfile-debian-ubuntu-package-install-debconf-noninteract
ARG DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update \
    && apt-get upgrade --yes \
    && apt-get install --yes --no-install-recommends \
    ca-certificates \
    locales \
    netbase \
    wget \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && echo "C.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen

# Set virtual environment variables in PATH
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create a virtual environment
RUN python3 -m venv /opt/venv

# Create a working directory and `cd` into it
WORKDIR /app

# Copy requirements.txt to WORKDIR with the correct ownership
COPY requirements.txt .

# Install python deps using pip as a module (ensures pip uses the correct python version)
RUN python -m pip install --no-cache-dir -r requirements.txt

FROM python:3.12.7-slim-bookworm

COPY --from=build /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_creating-a-nonroot-user
#ARG USERNAME=jovyan
#ARG USER_UID=1000
#ARG USER_GID=${USER_UID}
#RUN groupadd --gid ${USER_GID} ${USERNAME} \
#    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}

# Allow for port override at build time via ARG
# ENV is present at runtime (i.e., run `printenv` in the container)
ARG PORT=8888
ENV PORT=${PORT}

# # https://jupyterlab.readthedocs.io/en/stable/user/announcements.html
RUN jupyter labextension disable '@jupyterlab/apputils-extension:announcements'

# # https://jupyter-server.readthedocs.io/en/latest/operators/public-server.html#running-a-public-notebook-server
RUN jupyter server --generate-config

# # https://jupyter-server.readthedocs.io/en/latest/operators/security.html#security-in-the-jupyter-server
# #ARG JUPYTER_SERVER_CONFIG="/home/jovyan/.jupyter/jupyter_server_config.py"
ARG JUPYTER_SERVER_CONFIG="/root/.jupyter/jupyter_server_config.py"

# https://docs.docker.com/reference/dockerfile/#example-running-a-multi-line-script
RUN <<EOF
#!/bin/bash
set -e
tee "${JUPYTER_SERVER_CONFIG}" <<EOL
c = get_config()  #noqa
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.open_browser = False
c.ServerApp.port = ${PORT}

# # Token authentication
# c.IdentityProvider.token = ''      # Empty string disables token authentication
# c.PasswordIdentityProvider.hashed_password = ''   # Empty string allows no password

# Security settings
c.ServerApp.allow_remote_access = True
c.ServerApp.allow_origin = '*'
c.ServerApp.disable_check_xsrf = False
c.ServerApp.allow_root = False
c.ServerApp.base_url = '/'
EOL
EOF

# Document the ports that are exposed by the image
EXPOSE ${PORT}

# Create a working directory and `cd` into it
ARG APP_DIR=/app
WORKDIR ${APP_DIR}

# Give user permissions on WORKDIR
#RUN chown -R ${USERNAME}:${USERNAME} ${APP_DIR}

# Switch to non-root user
#USER ${USERNAME}

# https://jupyter-server.readthedocs.io/en/latest/operators/public-server.html#docker-cmd
# TARGETARCH is the architecture of the target platform (e.g., amd64, arm64, etc.)
ARG TINI_VERSION=v0.19.0
ARG TARGETARCH
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} /usr/bin/tini
RUN chmod +x /usr/bin/tini

# Use tini to reap zombie processes and stop the container gracefully via SIGINT/SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--"]

# Run the notebook server with $JUPYTER_SERVER_CONFIG
CMD ["jupyter", "lab"]
