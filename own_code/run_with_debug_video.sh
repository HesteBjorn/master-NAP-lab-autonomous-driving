#!/usr/bin/env bash

# Run a CARLA scenario with debug visualizations enabled and convert the frames into a video.
# Example:
#   own_code/run_with_debug_video.sh \
#     --route-tag route_00 \
#     --command "python leaderboard/leaderboard_evaluator.py --routes routes_devtest.xml --scenarios scenarios/all_towns_traffic_scenarios_public.json --repetitions 1 --agent team_code/sensor_agent.py --agent-config outputs/transfuser/checkpoint" \
#     --fps 12

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

declare -a ROUTE_TAGS=()
ROUTES_FILE=""
RUN_COMMAND=""
FPS=10

usage() {
  echo "Usage: $0 (--route-tag <name> | --routes-file <xml>) --command \"<leaderboard command>\" [--fps <n>]" >&2
  exit 1
}

while (($#)); do
  case "$1" in
    --route-tag)
      ROUTE_TAGS+=("${2:-}")
      shift 2
      ;;
    --routes-file)
      ROUTES_FILE="${2:-}"
      shift 2
      ;;
    --command)
      RUN_COMMAND="${2:-}"
      shift 2
      ;;
    --fps)
      FPS="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      ;;
  esac
done

if [[ ${#ROUTE_TAGS[@]} -eq 0 && -z "${ROUTES_FILE}" ]]; then
  echo "Error: provide at least one --route-tag or a --routes-file." >&2
  usage
fi

if [[ -z "${RUN_COMMAND}" ]]; then
  usage
fi

if [[ -n "${ROUTES_FILE}" ]]; then
  if [[ ! -f "${ROUTES_FILE}" ]]; then
    echo "Error: routes file ${ROUTES_FILE} not found." >&2
    exit 1
  fi
  mapfile -t XML_ROUTE_TAGS < <(python - "${ROUTES_FILE}" <<'PY'
import sys
import xml.etree.ElementTree as ET
tree = ET.parse(sys.argv[1])
root = tree.getroot()
ids = []
for route in root.findall('.//route'):
    route_id = route.get('id')
    if route_id:
        ids.append(route_id)
for rid in ids:
    print(rid)
PY
)
  if [[ ${#XML_ROUTE_TAGS[@]} -eq 0 ]]; then
    echo "Warning: no route ids found in ${ROUTES_FILE}." >&2
  else
    ROUTE_TAGS+=("${XML_ROUTE_TAGS[@]}")
  fi
fi

# Remove duplicates
if [[ ${#ROUTE_TAGS[@]} -eq 0 ]]; then
  echo "Error: no route tags available." >&2
  exit 1
fi
readarray -t ROUTE_TAGS < <(printf '%s\n' "${ROUTE_TAGS[@]}" | awk '!seen[$0]++')

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/setup_env.sh" --enable-debug

echo "Running scenario command:"
echo "${RUN_COMMAND}"
eval "${RUN_COMMAND}"

for ROUTE_TAG in "${ROUTE_TAGS[@]}"; do
  FRAME_DIR="${SAVE_PATH}/${ROUTE_TAG}"
  if [[ ! -d "${FRAME_DIR}" ]]; then
    fallback_dir="$(ls -dt "${SAVE_PATH}"/*"route${ROUTE_TAG}_"* 2>/dev/null | head -n 1 || true)"
    if [[ -n "${fallback_dir}" && -d "${fallback_dir}" ]]; then
      FRAME_DIR="${fallback_dir}"
      echo "Info: using detected folder ${FRAME_DIR} for route id ${ROUTE_TAG}."
    else
      echo "Warning: frame directory for tag ${ROUTE_TAG} not found, skipping." >&2
      continue
    fi
  fi
  python "${WORK_DIR}/own_code/vis_to_video.py" \
    --frames "${FRAME_DIR}" \
    --fps "${FPS}"
done

echo "Done."
