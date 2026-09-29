#!/usr/bin/env bash

# ------------------------------------- #
# --- Common Installation Functions --- #
# ------------------------------------- #

#
# Functions defined only when this script is sourced
#                   | When Executed             | When Sourced               |
# $0                | Path of the script itself | Path of the calling script |
# ${BASH_SOURCE[0]} | Path of the script itself | Path of the sourced file   |
#
# echo 
# echo "$0"
# echo "${BASH_SOURCE[0]}"
# echo 
# echo "$(cd -- "$(dirname -- "$0")" &>/dev/null && pwd)/"
# echo "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)/"

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then

  CALLING_SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" &>/dev/null && pwd)/"   
  VENV_DIR="$CALLING_SCRIPT_DIR.venv/"
  INSTALL_LOGS_DIR="$CALLING_SCRIPT_DIR.install_logs/"
  ACTIVATE_SCRIPT="$VENV_DIR/bin/activate"

  run_required() {
    local enum="$1"; shift
    local label="$1"; shift
    local log_file="$INSTALL_LOGS_DIR${enum}_${label//[^A-Za-z0-9]/_}.log"
    echo
    echo "  $label"
    if ! "$@" > "$log_file" 2>&1; then
      echo "    FAILED" >&2
      echo "    command  : $*" >&2
      echo "    log file : $log_file" >&2
      echo >&2
      exit 1
    fi
    echo "    DONE"
  }

  run_optional() {
    local enum="$1"; shift
    local label="$1"; shift
    local log_file="$INSTALL_LOGS_DIR${enum}_${label//[^A-Za-z0-9]/_}.log"
    echo
    echo "  $label"
    if ! "$@" > "$log_file" 2>&1; then
      echo "    FAILED (optional)"
      echo "    command  : $*"
      echo "    log file : $log_file"
    else
      echo "    DONE"
    fi
  }

  print_python_env() {
    local label="$1"
    local python_cmd_local="$2"
    local python_version="$($python_cmd_local --version 2>&1)"
    local python_path="$(command -v "$python_cmd_local" || true)"
    local pip_version="$($python_cmd_local -m pip --version 2>&1 || echo 'pip not found')"
    echo
    echo "  $label"
    echo "    Python Version : $python_version"
    echo "    Python Path    : $python_path"
    echo "    Pip Version    : $pip_version"
  }

  print_python_packages() {
    local python_cmd_local="$1"
    echo
    echo "  Local Pip Packages "
    echo
    $python_cmd_local -m pip list --local || true
  }

  remove_venv() {
    if [[ -d "$VENV_DIR" ]]; then
      echo
      echo "  Removing virtual environment at $VENV_DIR"
      rm -rf "$VENV_DIR"
      echo "    DONE"
    fi
    if [[ -d "$INSTALL_LOGS_DIR" ]]; then
      echo
      echo "  Removing .install_logs : $INSTALL_LOGS_DIR"
      rm -rf "$INSTALL_LOGS_DIR"
      echo "    DONE"
    fi
    mkdir -p "$INSTALL_LOGS_DIR"
  }

  prepare_native_python() {
    run_optional 1 "Upgrading native pip" $PYTHON_CMD -m pip install --upgrade pip
    run_required 2 "Installing native virtualenv" $PYTHON_CMD -m pip install virtualenv
  }

  make_venv() {
    local target_python="$1"
    if command -v $target_python >/dev/null 2>&1; then
      run_required 3 "Making virtual environment" $PYTHON_CMD -m virtualenv $VENV_DIR --clear --copies --python=$target_python
    else
      echo >&2
      echo "  Target python : $target_python : NOT FOUND"
      echo >&2
      exit 1
    fi
    chmod +x "$ACTIVATE_SCRIPT"
  }

  activate_venv() {
    echo
    echo "  Activating $VENV_DIR"
    if [[ ! -f "$ACTIVATE_SCRIPT" ]]; then
      echo "    FAILED" >&2
      echo "    $ACTIVATE_SCRIPT does NOT exist." >&2
      echo >&2
      exit 1
    fi
    source "$ACTIVATE_SCRIPT"
    if [[ -z "${VIRTUAL_ENV:-}" ]]; then
      echo "    FAILED" >&2
      echo "    VIRTUAL_ENV is not set after sourcing." >&2
      echo >&2
      exit 1
    fi
    echo "    DONE"
  }

  deactivate_venv() {
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
      echo
      echo "  Deactivating .venv : $VIRTUAL_ENV"
      if type deactivate >/dev/null 2>&1; then
        deactivate || true
      fi
      echo "    DONE"
    fi
  }

fi