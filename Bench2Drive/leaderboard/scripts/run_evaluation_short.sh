#!/bin/bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: run_evaluation_short.sh --agent PATH --config PATH [options]

Runs Bench2Drive on the 3-route subset defined in leaderboard/data/bench2drive3_short.xml.
Required arguments:
  --agent PATH      Path to the agent entry point (e.g. team_code/sensor_agent.py)
  --config PATH     Path to the agent config/checkpoint file

Optional arguments:
  --gpu ID          CUDA device index to run on (default: 0)
  --planner TYPE    Planner type passed to run_evaluation.sh (default: traj)
  --base-port PORT  CARLA server port (default: 30000)
  --tm-port PORT    CARLA traffic manager port (default: 50000)
  --save-dir DIR    Directory (relative to Bench2Drive root) to store outputs (default: eval_bench2drive3_short)
  -h, --help        Show this message

Note: source own_code/setup_env.sh before running so CARLA_ROOT and dependencies are available.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECT_ROOT="$(cd "${WORK_DIR}/.." && pwd)"
export WORK_DIR
cd "${WORK_DIR}"

ROUTES_FILE="${WORK_DIR}/leaderboard/data/bench2drive3_short.xml"

if [[ ! -f "${ROUTES_FILE}" ]]; then
  echo "Routes file not found: ${ROUTES_FILE}" >&2
  exit 1
fi

: "${CARLA_ROOT:?CARLA_ROOT must be set (source own_code/setup_env.sh first).}"

TEAM_AGENT=""
TEAM_CONFIG=""
GPU_RANK=0
PLANNER_TYPE="traj"
BASE_PORT=30000
BASE_TM_PORT=50000
SAVE_DIR_NAME="eval_bench2drive3_short"
BASE_CHECKPOINT_NAME="eval_bench2drive3_short"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)
      TEAM_AGENT="$2"
      shift 2
      ;;
    --config)
      TEAM_CONFIG="$2"
      shift 2
      ;;
    --gpu)
      GPU_RANK="$2"
      shift 2
      ;;
    --planner)
      PLANNER_TYPE="$2"
      shift 2
      ;;
    --base-port)
      BASE_PORT="$2"
      shift 2
      ;;
    --tm-port)
      BASE_TM_PORT="$2"
      shift 2
      ;;
    --save-dir)
      SAVE_DIR_NAME="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
	    esac
	  done

abspath() {
  python - <<'PY' "$1"
import os, sys
print(os.path.abspath(sys.argv[1]))
PY
}

resolve_required_path() {
  local value="$1"
  local label="$2"
  local candidate=""
  if [[ "${value}" = /* ]]; then
    candidate="${value}"
  elif [[ -e "${WORK_DIR}/${value}" ]]; then
    candidate="${WORK_DIR}/${value}"
  elif [[ -e "${PROJECT_ROOT}/${value}" ]]; then
    candidate="${PROJECT_ROOT}/${value}"
  else
    echo "${label} path '${value}' not found relative to Bench2Drive or project root." >&2
    exit 1
  fi
  abspath "${candidate}"
}

resolve_optional_path() {
  local value="$1"
  local candidate=""
  if [[ -z "${value}" ]]; then
    return 1
  fi
  if [[ "${value}" = /* ]]; then
    candidate="${value}"
  elif [[ -e "${WORK_DIR}/${value}" ]]; then
    candidate="${WORK_DIR}/${value}"
  elif [[ -e "${PROJECT_ROOT}/${value}" ]]; then
    candidate="${PROJECT_ROOT}/${value}"
  else
    return 1
  fi
  abspath "${candidate}"
}

if [[ -z "${TEAM_AGENT}" ]]; then
  echo "Missing required --agent argument." >&2
  usage
  exit 1
fi

if [[ -z "${TEAM_CONFIG}" ]]; then
  echo "Missing required --config argument." >&2
  usage
  exit 1
fi

TEAM_AGENT="$(resolve_required_path "${TEAM_AGENT}" "TEAM_AGENT")"

if [[ "${TEAM_CONFIG}" != *"+"* ]]; then
  if resolved_config="$(resolve_optional_path "${TEAM_CONFIG}")"; then
    TEAM_CONFIG="${resolved_config}"
  fi
fi

if [[ "${SAVE_DIR_NAME}" = /* ]]; then
  SAVE_PATH="${SAVE_DIR_NAME}"
else
  SAVE_PATH="${WORK_DIR}/${SAVE_DIR_NAME}"
fi
CHECKPOINT_ENDPOINT="${SAVE_PATH}/${BASE_CHECKPOINT_NAME}.json"

mkdir -p "${SAVE_PATH}"

PORT="${BASE_PORT}"
TM_PORT="${BASE_TM_PORT}"
IS_BENCH2DRIVE=True

prepend_pythonpath() {
  local entry="$1"
  if [[ -z "${entry}" ]]; then
    return
  fi
  case ":${PYTHONPATH:-}:" in
    *":${entry}:"*) ;;
    *)
      PYTHONPATH="${entry}:${PYTHONPATH:-}"
      ;;
  esac
}

prepend_pythonpath "${WORK_DIR}/leaderboard"
prepend_pythonpath "${WORK_DIR}/scenario_runner"
prepend_pythonpath "${CARLA_ROOT}/PythonAPI/carla"
if [[ -d "${PROJECT_ROOT}/team_code" ]]; then
  prepend_pythonpath "${PROJECT_ROOT}/team_code"
fi
if [[ -d "${PROJECT_ROOT}/own_code" ]]; then
  prepend_pythonpath "${PROJECT_ROOT}/own_code"
fi
export PYTHONPATH

echo "Running Bench2Drive short evaluation"
echo "  WORK_DIR: ${WORK_DIR}"
echo "  ROUTES: ${ROUTES_FILE}"
echo "  TEAM_AGENT: ${TEAM_AGENT}"
echo "  TEAM_CONFIG: ${TEAM_CONFIG}"
echo "  SAVE_PATH: ${SAVE_PATH}"
echo "  CHECKPOINT_ENDPOINT: ${CHECKPOINT_ENDPOINT}"
echo "  GPU_RANK: ${GPU_RANK}"
echo "  PLANNER_TYPE: ${PLANNER_TYPE}"
echo "  PORT/TM_PORT: ${PORT}/${TM_PORT}"


bash leaderboard/scripts/run_evaluation.sh \
  "${PORT}" \
  "${TM_PORT}" \
  "${IS_BENCH2DRIVE}" \
  "${ROUTES_FILE}" \
  "${TEAM_AGENT}" \
  "${TEAM_CONFIG}" \
  "${CHECKPOINT_ENDPOINT}" \
  "${SAVE_PATH}" \
  "${PLANNER_TYPE}" \
  "${GPU_RANK}"
