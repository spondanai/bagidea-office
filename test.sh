#!/usr/bin/env bash

set -e

echo "=== Running Daemon Tests ==="
cd daemon
node test.js
cd ..

echo "=== Tests completed successfully ==="
