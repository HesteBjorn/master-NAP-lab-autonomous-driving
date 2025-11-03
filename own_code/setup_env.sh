#!/usr/bin/env bash

# Sets up the environment for running TransFuser++ inference.
# Usage: source own_code/setup_env.sh [--start-carla]
# Tips:
#   - Source this script from your shell so that the exports persist:
#       source own_code/setup_env.sh
#   - Add the optional --start-carla flag to spawn a CARLA server in a new terminal.

set -euo pipefail

# Ensure the script is sourced, otherwise environment changes would be lost.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Please source this script instead of executing it:"
  echo "  source ${BASH_SOURCE[0]}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CARLA_ROOT="${WORK_DIR}/carla"
CONDA_ENV="garage_2"

maybe_source_conda() {
  if command -v conda >/dev/null 2>&1; then
    # Ensure the current shell has the conda activation hooks.
    if ! type conda 2>/dev/null | grep -q 'conda is a function'; then
      local conda_exe
      conda_exe="$(command -v conda)"
      eval "$("${conda_exe}" shell.bash hook)"
    fi
    return 0
  fi

  local candidates=(
    "${HOME}/miniconda3/etc/profile.d/conda.sh"
    "${HOME}/anaconda3/etc/profile.d/conda.sh"
    "/opt/conda/etc/profile.d/conda.sh"
  )

  for candidate in "${candidates[@]}"; do
    if [[ -f "${candidate}" ]]; then
      # shellcheck disable=SC1090
      source "${candidate}"
      return 0
    fi
  done

  echo "Could not find conda.sh. Please adjust the candidates list in own_code/setup_env.sh." >&2
  return 1
}

maybe_source_conda

if conda info --envs >/dev/null 2>&1; then
  if ! conda info --envs | grep -qE "^[* ]*${CONDA_ENV}(\\s|$)"; then
    echo "Conda environment '${CONDA_ENV}' not found. Make sure you created it with environment.yml." >&2
    return 1
  fi
  conda activate "${CONDA_ENV}"
else
  echo "Warning: 'conda info --envs' failed. Please ensure conda is initialised correctly." >&2
  return 1
fi

export WORK_DIR
export CARLA_ROOT

PYTHONPATH_ENTRIES=(
  "${CARLA_ROOT}/PythonAPI/carla"
  "${WORK_DIR}/scenario_runner"
  "${WORK_DIR}/leaderboard"
  "${WORK_DIR}/own_code"
)

for entry in "${PYTHONPATH_ENTRIES[@]}"; do
  case ":${PYTHONPATH:-}:" in
    *":${entry}:"*) ;;
    *)
      export PYTHONPATH="${entry}:${PYTHONPATH:-}"
      ;;
  esac
done

export PYTHONPATH

if [[ ! -x "${CARLA_ROOT}/CarlaUE4.sh" ]]; then
  echo "Warning: ${CARLA_ROOT}/CarlaUE4.sh not found or not executable. Run setup_carla.sh if needed." >&2
fi

start_carla_server() {
  local commands=()

  if command -v gnome-terminal >/dev/null 2>&1; then
    commands+=("gnome-terminal -- bash -lc 'cd \"${CARLA_ROOT}\" && ./CarlaUE4.sh'")
  fi
  if command -v konsole >/dev/null 2>&1; then
    commands+=("konsole --hold -e bash -lc 'cd \"${CARLA_ROOT}\" && ./CarlaUE4.sh'")
  fi
  if command -v xterm >/dev/null 2>&1; then
    commands+=("xterm -hold -e bash -lc 'cd \"${CARLA_ROOT}\" && ./CarlaUE4.sh'")
  fi

  if [[ ${#commands[@]} -eq 0 ]]; then
    echo "No supported terminal emulator (gnome-terminal, konsole, xterm) found. Start CARLA manually:" >&2
    echo "  cd \"${CARLA_ROOT}\" && ./CarlaUE4.sh" >&2
    return 1
  fi

  for cmd in "${commands[@]}"; do
    # shellcheck disable=SC1083
    eval "${cmd}" >/dev/null 2>&1 && return 0
  done

  echo "Failed to launch CARLA server automatically. Please start it manually:" >&2
  echo "  cd \"${CARLA_ROOT}\" && ./CarlaUE4.sh" >&2
  return 1
}

if [[ "${1:-}" == "--start-carla" ]]; then
  start_carla_server || true
fi

echo "Environment ready. Conda env: ${CONDA_ENV}"
echo "WORK_DIR=${WORK_DIR}"
echo "CARLA_ROOT=${CARLA_ROOT}"
