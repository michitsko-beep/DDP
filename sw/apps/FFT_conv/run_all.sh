#!/bin/bash
set -e

# ============================
# Paths
# ============================
APP_DIR="/project/tsmc65/users/mentcy/ws/my_k5_proj/sw/apps/FFT_conv"
SIM_DIR="/data/project/tsmc65/users/mentcy/ws/my_k5_proj/sim"
T0_DIR="${SIM_DIR}/t0"

GEN_PY="${APP_DIR}/gen_fft_test.py"
CHK_PY="${APP_DIR}/check_fft.py"

N="${1:-16}"

echo "========================================"
echo " RUN ALL: Generator -> K5 -> Checker"
echo " N=${N}"
echo " APP_DIR=${APP_DIR}"
echo " T0_DIR=${T0_DIR}"
echo "========================================"

# ============================
# 0) Prepare t0 folder
# ============================
mkdir -p "${T0_DIR}"

# ============================
# 1) Generate input/config INTO sim/t0
# ============================
echo ""
echo "[1] Generating input/config into sim/t0 ..."
cd "${T0_DIR}"
python3 "${GEN_PY}" "${N}"

echo ""
echo "[INFO] Generated files:"
ls -la fft_test_in.txt fft_test_config.txt

# ============================
# 2) Run K5 app (will read from sim/t0 and write fft_test_out.txt there)
# ============================
echo ""
echo "[2] Running K5 app FFT_conv ..."
cd "${SIM_DIR}"
launch_k5_app FFT_conv

# ============================
# 3) Run checker FROM sim/t0
# ============================
echo ""
echo "[3] Running checker in sim/t0 ..."
cd "${T0_DIR}"
python3 "${CHK_PY}"

echo ""
echo "✅ DONE."
