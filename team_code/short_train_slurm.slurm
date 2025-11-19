#!/bin/bash
#SBATCH --job-name=short_train
#SBATCH --partition=GPUQ
#SBATCH --account=ie-idi
#SBATCH --output=short_train_%j.log
#SBATCH --error=short_train_%j.errx
#SBATCH --time=00:15:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8

# IMPORTANT: Start this script from within team_code folder, otherwise it will not work

# print info about current job
scontrol show job $SLURM_JOB_ID

# SLURM_SUBMIT_DIR=${PWD}  # DISABLE ON IDUN
WORKDIR=${SLURM_SUBMIT_DIR}
PROJECT_ROOT="$(cd "${WORKDIR}/.." && pwd)"
cd ${WORKDIR}  # Enable on IDUN.
echo "we are running from this directory: $SLURM_SUBMIT_DIR"
echo " the name of the job is: $SLURM_JOB_NAME"
echo "Th job ID is $SLURM_JOB_ID"
echo "The job was run on these nodes: $SLURM_JOB_NODELIST"
echo "Number of nodes: $SLURM_JOB_NUM_NODES"
echo "We are using $SLURM_CPUS_ON_NODE cores"
echo "We are using $SLURM_CPUS_ON_NODE cores per node"
echo "Total of $SLURM_NTASKS cores"

module purge # Enable on idun
module load Anaconda3/2024.02-1  # Enable on idun
# source ~/miniconda3/etc/profile.d/conda.sh  # DISABLE on IDUN
conda env --list
conda activate garage_2
echo WORKDIR is $WORKDIR
which python

pwd
export CARLA_ROOT=/cluster/projects/vc/data/ad/open/write-folder/carla_0.9.15  # Enable on Idun
export SCENARIO_RUNNER_ROOT=${PROJECT_ROOT}/scenario_runner
export LEADERBOARD_ROOT=${PROJECT_ROOT}/leaderboard
export PYTHONPATH="${CARLA_ROOT}/PythonAPI/carla/":"${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}
# export PYTHONPATH="${PYTHONPATH:-}"  # For local debug
# export PYTHONPATH="${PYTHONPATH}:/cluster/home/erikhbj/.conda/envs/garage_2/bin/python3"  # Enable on Idun
# export PYTHONPATH="${PYTHONPATH}:~/.conda/envs/garage_2/bin/python"  # Enable on Idun
# export PYTHONPATH="$CARLA_ROOT/PythonAPI:$CARLA_ROOT/PythonAPI/carla:$CARLA_ROOT/PythonAPI/carla/dist/carla-0.9.15-py3.7-linux-x86_64.egg:${PYTHONPATH}"
# export PYTHONPATH="${CARLA_ROOT}/PythonAPI/carla/":"${SCENARIO_RUNNER_ROOT}":"${LEADERBOARD_ROOT}":${PYTHONPATH}
export PYTHONPATH=$PYTHONPATH:${PROJECT_ROOT}

export MASTER_ADDR=localhost
export NCCL_DEBUG=INFO


export OMP_NUM_THREADS=8
export OPENBLAS_NUM_THREADS=1

echo $PYTHONPATH
echo $CARLA_ROOT

# # Download short dat if not already present
# cd ${PROJECT_ROOT}/tools
# cat download_short_data.sh
# ./download_short_data.sh
# cd ${WORKDIR}

torchrun --nnodes=$SLURM_NNODES --nproc_per_node=2 --max_restarts=0 \
  --rdzv_backend=c10d --rdzv_endpoint="$HOSTNAME:29500" \
  train.py \
  --id short_debug_slurm_${SLURM_JOB_ID} \
  --epochs 2 \
  --batch_size 4 \
  --lr 3e-4 \
  --use_cosine_schedule 1 \
  --cosine_t0 1 \
  --setting all \
  --root_dir ../data_short/ \
  --logdir ../outputs/debug_short \
  --cpu_cores 8 \
  --num_repetitions 1 \
  --use_controller_input_prediction 1  # Do everything single-stage
