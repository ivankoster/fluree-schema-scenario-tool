#!/bin/bash
docker run --mount src="$(pwd)/demo-schema-parts",target=/usr/src/fsst/fluree_parts,type=bind -it fsst /usr/src/fsst/fsst_tests.sh
