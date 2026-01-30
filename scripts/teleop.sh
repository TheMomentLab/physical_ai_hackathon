#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/scripts/teleop_profiles.sh"

CONDA_ENV="lerobot"
PROFILE=""
CAMERAS=""
DISPLAY_DATA=""
DRY_RUN="false"
NO_CONDA="false"
ASSUME_YES="false"

OVERRIDE_ROBOT_TYPE=""
OVERRIDE_TELEOP_TYPE=""
OVERRIDE_ROBOT_PORT=""
OVERRIDE_TELEOP_PORT=""
OVERRIDE_ROBOT_ID=""
OVERRIDE_TELEOP_ID=""
OVERRIDE_CAM_TOP=""
OVERRIDE_CAM_FRONT=""
OVERRIDE_CAM_WIDTH=""
OVERRIDE_CAM_HEIGHT=""
OVERRIDE_CAM_FPS=""
OVERRIDE_CAM_FOURCC=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --list                         List available profiles
  --profile NAME                 Use profile NAME
  --robot-type TYPE              Override robot type (default: so101_follower)
  --teleop-type TYPE             Override teleop type (default: so101_leader)
  --robot-port PATH              Override robot port
  --teleop-port PATH             Override teleop port
  --robot-id ID                  Override robot id
  --teleop-id ID                 Override teleop id
  --cam-top PATH                 Override top camera device path
  --cam-front PATH               Override front camera device path
  --cam-width N                  Override camera width (default: 640)
  --cam-height N                 Override camera height (default: 480)
  --cam-fps N                    Override camera fps (default: 30)
  --cam-fourcc STR               Override camera fourcc (default: MJPG; set to "none" to omit)
  --cameras MODE                 none|front|top|dual (interactive if not set)
  --display-data BOOL            true|false (interactive if not set)
  --dry-run                      Print command without running
  --no-conda                     Skip conda activation
  --conda-env NAME               Conda env name (default: lerobot)
  --yes                          Assume yes for prompts
  -h, --help                     Show this help
EOF
}

msg() { printf "%s\n" "$*"; }
warn() { printf "WARN: %s\n" "$*" >&2; }
die() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

confirm() {
  local prompt="$1"
  if [[ "${ASSUME_YES}" == "true" ]]; then
    return 0
  fi
  read -r -p "${prompt} [y/N]: " reply
  [[ "${reply}" == "y" || "${reply}" == "Y" ]]
}

load_profiles() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
  fi
  if [[ -z "${PROFILES:-}" ]]; then
    PROFILES=("default")
    profile_default_robot_type="so101_follower"
    profile_default_teleop_type="so101_leader"
    profile_default_robot_port="/dev/follower_arm_1"
    profile_default_teleop_port="/dev/leader_arm_1"
    profile_default_robot_id="my_so101_follower_1"
    profile_default_teleop_id="my_so101_leader_1"
    profile_default_cam_top="/dev/top_cam_1"
    profile_default_cam_front="/dev/follower_cam_1"
    profile_default_cam_width="640"
    profile_default_cam_height="480"
    profile_default_cam_fps="30"
    profile_default_cam_fourcc="MJPG"
  fi
}

get_profile_var() {
  local profile="$1"
  local key="$2"
  local var="profile_${profile}_${key}"
  printf "%s" "${!var:-}"
}

list_profiles() {
  msg "Available profiles:"
  for p in "${PROFILES[@]}"; do
    msg "  - ${p}"
  done
}

pick_profile_interactive() {
  msg "Select a profile:"
  select p in "${PROFILES[@]}"; do
    if [[ -n "${p}" ]]; then
      PROFILE="${p}"
      break
    fi
  done
}

pick_cameras_interactive() {
  msg "Select camera mode:"
  select m in "none" "front" "top" "dual"; do
    if [[ -n "${m}" ]]; then
      CAMERAS="${m}"
      break
    fi
  done
}

pick_display_interactive() {
  msg "Enable display_data (rerun)?"
  select m in "true" "false"; do
    if [[ -n "${m}" ]]; then
      DISPLAY_DATA="${m}"
      break
    fi
  done
}

activate_conda() {
  if [[ "${NO_CONDA}" == "true" ]]; then
    return 0
  fi
  if [[ "${CONDA_DEFAULT_ENV:-}" == "${CONDA_ENV}" ]]; then
    return 0
  fi
  if ! command -v conda >/dev/null 2>&1; then
    warn "conda not found in PATH; continuing without activation."
    return 0
  fi
  local conda_base
  conda_base="$(conda info --base 2>/dev/null || true)"
  if [[ -z "${conda_base}" || ! -f "${conda_base}/etc/profile.d/conda.sh" ]]; then
    warn "conda.sh not found; continuing without activation."
    return 0
  fi
  # shellcheck source=/dev/null
  source "${conda_base}/etc/profile.d/conda.sh"
  conda activate "${CONDA_ENV}" || warn "conda activate ${CONDA_ENV} failed."
}

check_device() {
  local path="$1"
  if [[ -z "${path}" ]]; then
    return 0
  fi
  if [[ ! -e "${path}" ]]; then
    warn "Missing device: ${path}"
    return 1
  fi
  return 0
}

list_available_devices() {
  shopt -s nullglob
  local leaders=(/dev/leader_arm_*)
  local followers=(/dev/follower_arm_*)
  local tops=(/dev/top_cam_*)
  local fronts=(/dev/follower_cam_*)
  shopt -u nullglob
  msg "Detected devices:"
  msg "  leader arms : ${leaders[*]:-none}"
  msg "  follower arms: ${followers[*]:-none}"
  msg "  top cams    : ${tops[*]:-none}"
  msg "  front cams  : ${fronts[*]:-none}"
}

build_command() {
  local robot_type="$1"
  local teleop_type="$2"
  local robot_port="$3"
  local teleop_port="$4"
  local robot_id="$5"
  local teleop_id="$6"
  local cam_top="$7"
  local cam_front="$8"
  local cam_w="$9"
  local cam_h="${10}"
  local cam_fps="${11}"
  local cam_fourcc="${12}"
  local cameras_mode="${13}"
  local display="${14}"

  local fourcc_clause=""
  if [[ -n "${cam_fourcc}" && "${cam_fourcc}" != "none" ]]; then
    fourcc_clause=", fourcc: ${cam_fourcc}"
  fi

  local cam_json=""
  case "${cameras_mode}" in
    none|"")
      cam_json=""
      ;;
    front)
      cam_json="front: {type: opencv, index_or_path: ${cam_front}, width: ${cam_w}, height: ${cam_h}, fps: ${cam_fps}${fourcc_clause}}"
      ;;
    top)
      cam_json="top: {type: opencv, index_or_path: ${cam_top}, width: ${cam_w}, height: ${cam_h}, fps: ${cam_fps}${fourcc_clause}}"
      ;;
    dual)
      cam_json="top: {type: opencv, index_or_path: ${cam_top}, width: ${cam_w}, height: ${cam_h}, fps: ${cam_fps}${fourcc_clause}}, front: {type: opencv, index_or_path: ${cam_front}, width: ${cam_w}, height: ${cam_h}, fps: ${cam_fps}${fourcc_clause}}"
      ;;
    *)
      die "Unknown cameras mode: ${cameras_mode}"
      ;;
  esac

  CMD=(lerobot-teleoperate
    --robot.type="${robot_type}"
    --robot.port="${robot_port}"
    --robot.id="${robot_id}"
    --teleop.type="${teleop_type}"
    --teleop.port="${teleop_port}"
    --teleop.id="${teleop_id}"
  )
  if [[ -n "${cam_json}" ]]; then
    CMD+=(--robot.cameras="{ ${cam_json} }")
  fi
  if [[ -n "${display}" ]]; then
    CMD+=(--display_data="${display}")
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        load_profiles
        list_profiles
        exit 0
        ;;
      --profile)
        PROFILE="$2"; shift 2 ;;
      --robot-type)
        OVERRIDE_ROBOT_TYPE="$2"; shift 2 ;;
      --teleop-type)
        OVERRIDE_TELEOP_TYPE="$2"; shift 2 ;;
      --robot-port)
        OVERRIDE_ROBOT_PORT="$2"; shift 2 ;;
      --teleop-port)
        OVERRIDE_TELEOP_PORT="$2"; shift 2 ;;
      --robot-id)
        OVERRIDE_ROBOT_ID="$2"; shift 2 ;;
      --teleop-id)
        OVERRIDE_TELEOP_ID="$2"; shift 2 ;;
      --cam-top)
        OVERRIDE_CAM_TOP="$2"; shift 2 ;;
      --cam-front)
        OVERRIDE_CAM_FRONT="$2"; shift 2 ;;
      --cam-width)
        OVERRIDE_CAM_WIDTH="$2"; shift 2 ;;
      --cam-height)
        OVERRIDE_CAM_HEIGHT="$2"; shift 2 ;;
      --cam-fps)
        OVERRIDE_CAM_FPS="$2"; shift 2 ;;
      --cam-fourcc)
        OVERRIDE_CAM_FOURCC="$2"; shift 2 ;;
      --cameras)
        CAMERAS="$2"; shift 2 ;;
      --display-data)
        DISPLAY_DATA="$2"; shift 2 ;;
      --dry-run)
        DRY_RUN="true"; shift ;;
      --no-conda)
        NO_CONDA="true"; shift ;;
      --conda-env)
        CONDA_ENV="$2"; shift 2 ;;
      --yes)
        ASSUME_YES="true"; shift ;;
      -h|--help)
        usage; exit 0 ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  load_profiles
  if [[ -z "${PROFILE}" ]]; then
    pick_profile_interactive
  fi

  local robot_type teleop_type robot_port teleop_port robot_id teleop_id
  local cam_top cam_front cam_w cam_h cam_fps cam_fourcc

  robot_type="${OVERRIDE_ROBOT_TYPE:-$(get_profile_var "${PROFILE}" "robot_type")}"
  teleop_type="${OVERRIDE_TELEOP_TYPE:-$(get_profile_var "${PROFILE}" "teleop_type")}"
  robot_port="${OVERRIDE_ROBOT_PORT:-$(get_profile_var "${PROFILE}" "robot_port")}"
  teleop_port="${OVERRIDE_TELEOP_PORT:-$(get_profile_var "${PROFILE}" "teleop_port")}"
  robot_id="${OVERRIDE_ROBOT_ID:-$(get_profile_var "${PROFILE}" "robot_id")}"
  teleop_id="${OVERRIDE_TELEOP_ID:-$(get_profile_var "${PROFILE}" "teleop_id")}"
  cam_top="${OVERRIDE_CAM_TOP:-$(get_profile_var "${PROFILE}" "cam_top")}"
  cam_front="${OVERRIDE_CAM_FRONT:-$(get_profile_var "${PROFILE}" "cam_front")}"
  cam_w="${OVERRIDE_CAM_WIDTH:-$(get_profile_var "${PROFILE}" "cam_width")}"
  cam_h="${OVERRIDE_CAM_HEIGHT:-$(get_profile_var "${PROFILE}" "cam_height")}"
  cam_fps="${OVERRIDE_CAM_FPS:-$(get_profile_var "${PROFILE}" "cam_fps")}"
  cam_fourcc="${OVERRIDE_CAM_FOURCC:-$(get_profile_var "${PROFILE}" "cam_fourcc")}"

  if [[ -z "${CAMERAS}" ]]; then
    pick_cameras_interactive
  fi
  if [[ -z "${DISPLAY_DATA}" ]]; then
    pick_display_interactive
  fi

  msg "Profile: ${PROFILE}"
  msg "Robot  : ${robot_type} ${robot_port} id=${robot_id}"
  msg "Teleop : ${teleop_type} ${teleop_port} id=${teleop_id}"
  msg "Cameras: ${CAMERAS} (top=${cam_top}, front=${cam_front}, fourcc=${cam_fourcc:-none})"
  msg "Display: ${DISPLAY_DATA}"

  list_available_devices

  local missing=0
  check_device "${robot_port}" || missing=1
  check_device "${teleop_port}" || missing=1
  if [[ "${CAMERAS}" == "top" || "${CAMERAS}" == "dual" ]]; then
    check_device "${cam_top}" || missing=1
  fi
  if [[ "${CAMERAS}" == "front" || "${CAMERAS}" == "dual" ]]; then
    check_device "${cam_front}" || missing=1
  fi
  if [[ "${missing}" -eq 1 ]]; then
    if ! confirm "Some devices are missing. Continue anyway?"; then
      exit 1
    fi
  fi

  activate_conda

  if ! command -v lerobot-teleoperate >/dev/null 2>&1; then
    warn "lerobot-teleoperate not found in PATH."
    warn "If you use conda, ensure env '${CONDA_ENV}' is activated."
  fi

  build_command "${robot_type}" "${teleop_type}" "${robot_port}" "${teleop_port}" \
    "${robot_id}" "${teleop_id}" "${cam_top}" "${cam_front}" \
    "${cam_w}" "${cam_h}" "${cam_fps}" "${cam_fourcc}" "${CAMERAS}" "${DISPLAY_DATA}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    printf "Command:\n  "
    printf "%q " "${CMD[@]}"
    printf "\n"
    exit 0
  fi

  msg "Starting teleoperation..."
  "${CMD[@]}"
}

main "$@"
