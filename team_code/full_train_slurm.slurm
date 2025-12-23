#!/bin/bash
#SBATCH --job-name=full_train_attn
#SBATCH --partition=GPUQ
#SBATCH --account=ie-idi
#SBATCH --output=full_train_attn_%j.log
#SBATCH --error=full_train_attn_%j.err
#SBATCH --time=0-00:30:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:4
#SBATCH --constraint=a100
#SBATCH --mem=64G
#SBATCH --cpus-per-task=32

#SBATCH --mail-user=erikhbj@stud.ntnu.no
#SBATCH --mail-type=ALL

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


export OMP_NUM_THREADS=32
export OPENBLAS_NUM_THREADS=1

echo $PYTHONPATH
echo $CARLA_ROOT

# # Download short dat if not already present
# cd ${PROJECT_ROOT}/tools
# cat download_short_data.sh
# ./download_short_data.sh
# cd ${WORKDIR}

MASTER_PORT=$((29500 + SLURM_JOB_ID % 1000))
echo "MASTER PORT is $HOSTNAME:$MASTER_PORT"

torchrun --nnodes=$SLURM_NNODES --nproc_per_node=4 --max_restarts=0 \
  --rdzv_backend=c10d --rdzv_endpoint="$HOSTNAME:$MASTER_PORT" \
  train.py \
  --id full_train_attn_${SLURM_JOB_ID} \
  --epochs 31 \
  --batch_size 16 \
  --lr 3e-4 \
  --use_cosine_schedule 1 \
  --cosine_t0 1 \
  --setting all \
  --tp_attention 1 \
  --root_dir /cluster/projects/vc/data/ad/open/TransFuserPlusPlus/leaderboard_2 \
  --logdir ../outputs/full_train \
  --cpu_cores 32 \
  --num_repetitions 1 \
  --use_controller_input_prediction 0  # First stage
  # --use_controller_input_prediction 1  # Second stage \
  # --continue_epoch 0 \
  # --load_file ../outputs/full_train/full_train_attn_XXXX/model_XXX.pth


## TODO: ASK GPT:
# Double check the tp_attention and explain all of its consequences. Try to look for alternatives to re-implementing the transformer from scratch.
### Prompt: Thoroughly look through the tp_attention flag from train.py / config and explain me what it does. I want to know the entire flow and everywhere where the parameter influences the running code and architecture. I want to know the difference in detail in what is changed when it is turned on. When the architecture changes, how different will it be? What is the differences? What difference will it make in practice? Does the code and the architecture change work? Think through your answer thoroughly, and evaluate your correctness before stating the solution to me.

# # AND:
# Look through my training script, and ensure everything is correct. And make sure it fits my gpu setups etc. Look for potential failure ases
