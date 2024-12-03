# my_jupyterlab

Annotated docker image for running a Jupyter notebook with the MetPy library.

## Minimum Requirements

- [docker](https://docs.docker.com/get-docker/)
- [docker-compose](https://docs.docker.com/compose/install/)

## Recommended Requirements

- [python 3.12+](https://www.python.org/downloads/)
- [asdf](https://asdf-vm.com/#/)
- [poetry](https://python-poetry.org/docs/)

## Quickstart

### Docker

```bash
# build the image
docker build -t metpy_test .

# run the container
docker run -it --rm -p 8888:8888 -v $(pwd):/home/jovyan metpy_test
```

### Docker Compose

```bash
# build
docker compose build

# run the container
docker compose up

# build and run the container
docker compose up --build

# run the container in the background
docker compose up -d

# stop the container
docker compose stop

# remove the container and default bridge network
docker compose down
```

## TODO

- [ ] Add `asdf`
- [ ] Add `poetry`
- [ ] Add `.dockerignore`
- [ ] Add `hadolint` and lint Dockerfile
- [ ] Add `dive` and reduce image size
- [ ] Migrate to `alpine` (along with musl libc changes)
- [ ] Create multistage build: `Docker.multistage`
- [ ] Setup CI to auto publish to docker.io and ghcr.io registries
