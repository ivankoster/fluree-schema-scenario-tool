#!/bin/bash
docker run --mount src="$(pwd)/$1",target=/usr/src/fsst/fluree_parts,type=bind -it pibara/fsst:beta
