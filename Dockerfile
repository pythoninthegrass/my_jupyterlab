# syntax=docker/dockerfile:1.7.0

# Set full semantic version of the base image with variant tag
ARG ROOT_IMAGE=python:3.12.7-alpine3.20
FROM ${ROOT_IMAGE}

# https://github.com/jupyter/docker-stacks/blob/main/images/docker-stacks-foundation/Dockerfile

# Install required packages
RUN apk update \
    && apk upgrade \
    && apk add --no-cache \
    ca-certificates \
    gcc \
    linux-headers \
    musl-dev \
    musl-locales \
    musl-locales-lang \
    net-tools \
    proj \
    proj-dev \
    proj-util \
    python3-dev \
    tini \
    wget \
    && rm -rf /var/cache/apk/* \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.conf \
    && echo "C.UTF-8 UTF-8" >> /etc/locale.conf

ENV LANG en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

ENV PROJ_DIR=/usr
ENV PROJ_LIBDIR=/usr/lib
ENV PROJ_INCDIR=/usr/include/proj

# https://jupyter-server.readthedocs.io/en/latest/operators/public-server.html#docker-cmd
# TARGETARCH is the architecture of the target platform (e.g., amd64, arm64, etc.)
#ARG TINI_VERSION=v0.19.0
#ARG TARGETARCH
#ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-${TARGETARCH} /usr/bin/tini
#RUN chmod +x /usr/bin/tini

# Set virtual environment variables in PATH
ENV VIRTUAL_ENV=/opt/venv
ENV PATH="${VIRTUAL_ENV}/bin:$PATH"

# Create a virtual environment
RUN python3 -m venv ${VIRTUAL_ENV}

# https://code.visualstudio.com/remote/advancedcontainers/add-nonroot-user#_creating-a-nonroot-user
ARG USERNAME=jovyan
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
RUN addgroup -g ${USER_GID} ${USERNAME} \
    && adduser -u ${USER_UID} -G ${USERNAME} -D -s /bin/sh ${USERNAME}

# Create a working directory and `cd` into it
ARG APP_DIR=/app
WORKDIR ${APP_DIR}

# Copy requirements.txt to WORKDIR with the correct ownership
COPY --chown=${USERNAME}:${USERNAME} requirements.txt .

# Install python deps using pip as a module (ensures pip uses the correct python version)
RUN python -m pip install --no-cache-dir -r requirements.txt

# https://jupyterlab.readthedocs.io/en/stable/user/announcements.html
RUN jupyter labextension disable '@jupyterlab/apputils-extension:announcements'

# Give user permissions on WORKDIR
RUN chown -R ${USERNAME}:${USERNAME} ${APP_DIR}

# Switch to non-root user
USER ${USERNAME}

# Allow for port override at build time via ARG
# ENV is present at runtime (i.e., run `printenv` in the container)
ARG PORT=8888
ENV PORT=${PORT}

# https://jupyter-server.readthedocs.io/en/latest/operators/public-server.html#running-a-public-notebook-server
RUN jupyter server --generate-config

# https://jupyter-server.readthedocs.io/en/latest/operators/security.html#security-in-the-jupyter-server
ARG JUPYTER_SERVER_CONFIG="/home/${USERNAME}/.jupyter/jupyter_server_config.py"

# https://docs.docker.com/reference/dockerfile/#example-running-a-multi-line-script
RUN <<EOF
#!/bin/sh
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

# Use tini to reap zombie processes and stop the container gracefully via SIGINT/SIGTERM
ENTRYPOINT ["/sbin/tini", "--"]

# Run the notebook server with $JUPYTER_SERVER_CONFIG
CMD ["jupyter", "lab"]
