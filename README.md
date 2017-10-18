# Task Master

[![Docker Build Statu](https://img.shields.io/docker/build/timgreen/task-master.svg)](https://hub.docker.com/r/timgreen/task-master/)
[![Docker Automated build](https://img.shields.io/docker/automated/timgreen/task-master.svg)](https://hub.docker.com/r/timgreen/task-master/)
[![Docker Stars](https://img.shields.io/docker/stars/timgreen/task-master.svg)](https://hub.docker.com/r/timgreen/task-master/)
[![Docker Pulls](https://img.shields.io/docker/pulls/timgreen/task-master.svg)](https://hub.docker.com/r/timgreen/task-master/)

## Pick The Right Image

| Tag     | Dind               | Graph Easy         | Papertrail         | Layers      |
| ------- | ------------------ | ------------------ | ------------------ | ----------- |
| latest  | :heavy_check_mark: | :heavy_check_mark: | :heavy_check_mark: | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master.svg)](https://microbadger.com/images/timgreen/task-master) |
| minimum |                    |                    |                    | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:minimum.svg)](https://microbadger.com/images/timgreen/task-master) |
| d       | :heavy_check_mark: |                    |                    | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:d.svg)](https://microbadger.com/images/timgreen/task-master) |
| g       |                    | :heavy_check_mark: |                    | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:g.svg)](https://microbadger.com/images/timgreen/task-master) |
| p       |                    |                    | :heavy_check_mark: | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:p.svg)](https://microbadger.com/images/timgreen/task-master) |
| dg      | :heavy_check_mark: | :heavy_check_mark: |                    | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:dg.svg)](https://microbadger.com/images/timgreen/task-master) |
| dp      | :heavy_check_mark: |                    | :heavy_check_mark: | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:dp.svg)](https://microbadger.com/images/timgreen/task-master) |
| gp      |                    | :heavy_check_mark: | :heavy_check_mark: | [![ImageLayers](https://images.microbadger.com/badges/image/timgreen/task-master:gp.svg)](https://microbadger.com/images/timgreen/task-master) |

## Usage

**Recommand**, use docker-compose, [example config](./examples/hello-world/docker-compose.yml).

    docker-compose up

Or for simple use case (don't need dind).

    docker run -v $PWD/config.yaml:/config.yaml timgreen/task-master

