#!/bin/bash
docker build -t pibara/fsst:stable -t pibara/fsst:fluree-0.14.1 .
docker build -t pibara/fsst:beta -t pibara/fsst:fluree-0.15.7 . -f Dockerfile-latest
