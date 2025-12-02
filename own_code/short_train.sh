#!/usr/bin/env bash
set -euo pipefail

cd /home/erikhbj/Documents/master/master-NAP-lab-autonomous-driving
export CARLA_ROOT=~/software/CARLA_Leaderboard_20
export PYTHONPATH="${PYTHONPATH:-}"
export PYTHONPATH="$CARLA_ROOT/PythonAPI:$CARLA_ROOT/PythonAPI/carla:$CARLA_ROOT/PythonAPI/carla/dist/carla-0.9.15-py3.7-linux-x86_64.egg:${PYTHONPATH}"
export OMP_NUM_THREADS=8
export OPENBLAS_NUM_THREADS=1
export RANK=0 WORLD_SIZE=1 LOCAL_RANK=0
export TORCH_INIT_METHOD="file://$(mktemp /tmp/c10d_init_XXXXXX)"

torchrun --nnodes=1 --nproc_per_node=1 --max_restarts=1 \
    --rdzv_backend=c10d --rdzv_endpoint=127.0.0.1:29500 \
  team_code/train.py \
  --id short_debug_script2 \
  --epochs 5 \
  --batch_size 4 \
  --lr 1.875e-4 \
  --setting all \
  --root_dir /home/erikhbj/Documents/master/master-NAP-lab-autonomous-driving/data_short/ \
  --logdir /home/erikhbj/Documents/master/master-NAP-lab-autonomous-driving/outputs/debug_short \
  --cpu_cores 8 \
  --num_repetitions 1 \
  --use_controller_input_prediction 0
