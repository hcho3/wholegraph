#!/bin/bash
# Copyright (c) 2022-2024, NVIDIA CORPORATION.

set -euo pipefail

# Support invoking test_cpp.sh outside the script directory
cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")"/../

. /opt/conda/etc/profile.d/conda.sh

rapids-logger "Generate C++ testing dependencies"
rapids-dependency-file-generator \
  --output conda \
  --file_key test_cpp \
  --matrix "cuda=${RAPIDS_CUDA_VERSION%.*};arch=$(arch)" | tee env.yaml

rapids-mamba-retry env create --yes -f env.yaml -n test

# Temporarily allow unbound variables for conda activation.
set +u
conda activate test
set -u

CPP_CHANNEL=$(rapids-download-conda-from-s3 cpp)
RAPIDS_TESTS_DIR=${RAPIDS_TESTS_DIR:-"${PWD}/test-results"}/
mkdir -p "${RAPIDS_TESTS_DIR}"

rapids-print-env

PACKAGES="libwholegraph libwholegraph-tests"

rapids-mamba-retry install \
  --channel "${CPP_CHANNEL}" \
  "${PACKAGES}"

rapids-logger "Check GPU usage"
nvidia-smi

# Run libwholegraph tests from libwholegraph-tests package
rapids-logger "Run tests"
./ci/run_ctests.sh && EXITCODE=$? || EXITCODE=$?

rapids-logger "Test script exiting with value: $EXITCODE"
exit ${EXITCODE}
