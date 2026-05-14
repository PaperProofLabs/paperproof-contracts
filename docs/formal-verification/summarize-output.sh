#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

packages=("$@")
if [ "${#packages[@]}" -eq 0 ]; then
  packages=(
    "comments-specs"
    "governance-specs"
    "publishing-specs"
  )
fi

print_group() {
  local label="$1"
  shift
  local items=("$@")

  echo "${label} (${#items[@]})"
  if [ "${#items[@]}" -eq 0 ]; then
    echo "  -"
    return
  fi

  printf '%s\n' "${items[@]}" | sort | sed 's/^/  /'
}

is_known_toolchain_blocked() {
  local base="$1"
  case "$base" in
    governance_spec::execute_proposal_spec|\
    publishing_spec::publish_reserved_preprint_common_spec|\
    publishing_spec::finalize_reserved_preprint_spec|\
    publishing_spec::add_preprint_version_spec)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

for package in "${packages[@]}"; do
  output_dir="$ROOT_DIR/$package/output"
  echo "== $package =="

  if [ ! -d "$output_dir" ]; then
    echo "missing output/"
    echo
    continue
  fi

  declare -A bases=()
  declare -A check_files=()
  declare -A check_logs=()
  declare -A processed_logs=()

  while IFS= read -r -d '' path; do
    name="$(basename "$path")"
    case "$name" in
      *_Check.bpl)
        base="${name%_Check.bpl}"
        bases["$base"]=1
        check_files["$base"]="$path"
        ;;
      *_Check.bpl.log)
        base="${name%_Check.bpl.log}"
        bases["$base"]=1
        check_logs["$base"]="$path"
        ;;
      *.log.txt)
        base="${name%.log.txt}"
        bases["$base"]=1
        processed_logs["$base"]="$path"
        ;;
    esac
  done < <(find "$output_dir" -maxdepth 1 -type f -print0)

  green=()
  failed=()
  toolchain_blocked=()
  check_only=()
  processed_only=()

  while IFS= read -r base; do
    check_file="${check_files[$base]:-}"
    check_log="${check_logs[$base]:-}"
    processed_log="${processed_logs[$base]:-}"

    if is_known_toolchain_blocked "$base"; then
      toolchain_blocked+=("$base")
      continue
    fi

    if [ -n "$check_file" ]; then
      if [ -z "$check_log" ]; then
        check_only+=("$base")
        continue
      fi

      check_mtime="$(stat -c %Y "$check_file")"
      log_mtime="$(stat -c %Y "$check_log")"
      if [ "$log_mtime" -lt "$check_mtime" ]; then
        check_only+=("$base")
        continue
      fi

      if grep -Eq 'assert_failed|finished with [1-9][0-9]* errors' "$check_log"; then
        failed+=("$base")
      elif grep -Eq '(^|[^0-9])0 errors([^0-9]|$)|Verification successful' "$check_log"; then
        green+=("$base")
      else
        check_only+=("$base")
      fi
    elif [ -n "$processed_log" ]; then
      processed_only+=("$base")
    fi
  done < <(printf '%s\n' "${!bases[@]}" | sort)

  print_group "green" "${green[@]}"
  print_group "failed" "${failed[@]}"
  print_group "toolchain-blocked" "${toolchain_blocked[@]}"
  print_group "check-only" "${check_only[@]}"
  print_group "processed-only" "${processed_only[@]}"
  echo
done
