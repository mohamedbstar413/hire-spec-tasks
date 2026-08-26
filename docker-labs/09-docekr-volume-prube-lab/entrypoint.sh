#!/bin/bash

set -euo pipefail

for i in $(seq 1 100); do
    docker volume create "volume-$i" >/dev/null
done

exec /bin/bash
