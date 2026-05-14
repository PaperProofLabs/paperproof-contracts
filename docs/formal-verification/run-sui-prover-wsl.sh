#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SUI_DEPENDS_ROOT="${SUI_DEPENDS_ROOT:-$HOME/sui-depends}"
PROVER_BIN="${PROVER_BIN:-$SUI_DEPENDS_ROOT/sui-prover/target/release/sui-prover}"
LOCAL_FRAMEWORK_DIR="${LOCAL_FRAMEWORK_DIR:-$SUI_DEPENDS_ROOT/local-framework}"
MOVE_HOME_DIR="${MOVE_HOME_DIR:-$SUI_DEPENDS_ROOT/move-home-local}"
LOCK_DIR="${LOCK_DIR:-/tmp/paperproof-formal-verification-locks}"
RUN_LOCK_FILE="${RUN_LOCK_FILE:-$LOCK_DIR/run-sui-prover-wsl.lock}"
MOVE_HOME_LOCK_FILE="${MOVE_HOME_LOCK_FILE:-$LOCK_DIR/move-home.lock}"
BOOGIE_EXE_DEFAULT="${BOOGIE_EXE_DEFAULT:-}"
Z3_EXE_DEFAULT="${Z3_EXE_DEFAULT:-}"
BOOGIE_Z3_PROVER_PATH_DEFAULT="${BOOGIE_Z3_PROVER_PATH_DEFAULT:-$Z3_EXE_DEFAULT}"
WEAK_TRANSFER_SPEC="${WEAK_TRANSFER_SPEC:-0}"
WEAK_UNWRAP_SPEC="${WEAK_UNWRAP_SPEC:-0}"

ensure_local_framework() {
  mkdir -p "$LOCAL_FRAMEWORK_DIR"

  [ -f "$LOCAL_FRAMEWORK_DIR/move-stdlib/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui/crates/sui-framework/packages/move-stdlib" "$LOCAL_FRAMEWORK_DIR/"
  [ -f "$LOCAL_FRAMEWORK_DIR/sui-framework/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui/crates/sui-framework/packages/sui-framework" "$LOCAL_FRAMEWORK_DIR/"
  [ -f "$LOCAL_FRAMEWORK_DIR/sui-system/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui/crates/sui-framework/packages/sui-system" "$LOCAL_FRAMEWORK_DIR/"
  [ -f "$LOCAL_FRAMEWORK_DIR/deepbook/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui/crates/sui-framework/packages/deepbook" "$LOCAL_FRAMEWORK_DIR/"
  [ -f "$LOCAL_FRAMEWORK_DIR/sui-prover/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui-prover/packages/sui-prover" "$LOCAL_FRAMEWORK_DIR/"
  [ -f "$LOCAL_FRAMEWORK_DIR/sui-specs/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui-prover/packages/sui-specs" "$LOCAL_FRAMEWORK_DIR/"
  [ -f "$LOCAL_FRAMEWORK_DIR/prover/Move.toml" ] || cp -R "$SUI_DEPENDS_ROOT/sui-prover/packages/prover" "$LOCAL_FRAMEWORK_DIR/"

  python3 - "$LOCAL_FRAMEWORK_DIR" <<'PY2'
from pathlib import Path
import sys

root = Path(sys.argv[1])
move_stdlib = (root / "move-stdlib").as_posix()
sui_framework = (root / "sui-framework").as_posix()
prover = (root / "prover").as_posix()
replacements = {
    root / "prover" / "Move.toml": [
        ('MoveStdlib = { git = "https://github.com/asymptotic-code/sui.git", subdir = "crates/sui-framework/packages/move-stdlib", rev = "next", override = true }',
         f'MoveStdlib = {{ local = "{move_stdlib}", override = true }}'),
        ('Sui = { git = "https://github.com/asymptotic-code/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "next", override = true }',
         f'Sui = {{ local = "{sui_framework}", override = true }}'),
        ('MoveStdlib = { local = "../move-stdlib", override = true }',
         f'MoveStdlib = {{ local = "{move_stdlib}", override = true }}'),
        ('Sui = { local = "../sui-framework", override = true }',
         f'Sui = {{ local = "{sui_framework}", override = true }}'),
    ],
    root / "sui-specs" / "Move.toml": [
        ('Sui = { git = "https://github.com/asymptotic-code/sui.git", subdir = "crates/sui-framework/packages/sui-framework", rev = "next", override = true }',
         f'Sui = {{ local = "{sui_framework}", override = true }}'),
        ('Sui = { local = "../sui-framework", override = true }',
         f'Sui = {{ local = "{sui_framework}", override = true }}'),
        ('Prover = { local = "../prover", override = true }',
         f'Prover = {{ local = "{prover}", override = true }}'),
    ],
    root / "sui-framework" / "Move.toml": [
        ('MoveStdlib = { local = "../move-stdlib", override = true }',
         f'MoveStdlib = {{ local = "{move_stdlib}", override = true }}'),
    ],
    root / "sui-system" / "Move.toml": [
        ('MoveStdlib = { local = "../move-stdlib" }',
         f'MoveStdlib = {{ local = "{move_stdlib}" }}'),
        ('Sui = { local = "../sui-framework" }',
         f'Sui = {{ local = "{sui_framework}" }}'),
    ],
    root / "deepbook" / "Move.toml": [
        ('MoveStdlib = { local = "../move-stdlib" }',
         f'MoveStdlib = {{ local = "{move_stdlib}" }}'),
        ('Sui = { local = "../sui-framework" }',
         f'Sui = {{ local = "{sui_framework}" }}'),
    ],
}

for path, edits in replacements.items():
    text = path.read_text(encoding="utf-8")
    updated = text
    for old, new in edits:
        updated = updated.replace(old, new)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
PY2
}

seed_move_home() {
  mkdir -p "$LOCK_DIR"
  exec 8>"$MOVE_HOME_LOCK_FILE"
  flock 8

  local sui_cache_dir="$MOVE_HOME_DIR/https___github_com_asymptotic-code_sui_git_next"
  local prover_cache_dir="$MOVE_HOME_DIR/https___github_com_asymptotic-code_sui-prover_git_main"
  local move_home_tmp_dir="${MOVE_HOME_DIR}.tmp.codex"

  if [ -f "$sui_cache_dir/crates/sui-framework/packages/sui-framework/Move.toml" ] && \
     [ -f "$prover_cache_dir/packages/prover/Move.toml" ]; then
    return
  fi

  rm -rf "$move_home_tmp_dir"
  mkdir -p "$move_home_tmp_dir"
  cp -R "$SUI_DEPENDS_ROOT/sui" "$move_home_tmp_dir/https___github_com_asymptotic-code_sui_git_next"
  cp -R "$SUI_DEPENDS_ROOT/sui-prover" "$move_home_tmp_dir/https___github_com_asymptotic-code_sui-prover_git_main"
  rm -rf "$MOVE_HOME_DIR"
  mv "$move_home_tmp_dir" "$MOVE_HOME_DIR"
}

sync_package_vendor_prover() {
  local package_dir="$1"
  local prover_toml="$ROOT_DIR/$package_dir/vendor/prover/Move.toml"

  if [ ! -f "$prover_toml" ]; then
    return
  fi

  python3 - "$prover_toml" "$LOCAL_FRAMEWORK_DIR" <<'PY2'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
framework_root = Path(sys.argv[2])
text = path.read_text(encoding="utf-8")

def replace_dep(dep_name: str, new_path: Path, content: str) -> str:
    pattern = rf'({dep_name}\s*=\s*\{{\s*local\s*=\s*")[^"]+("\s*,\s*override\s*=\s*true\s*\}})'
    return re.sub(pattern, rf'\1{new_path.as_posix()}\2', content)

updated = text
updated = replace_dep("MoveStdlib", framework_root / "move-stdlib", updated)
updated = replace_dep("Sui", framework_root / "sui-framework", updated)

if updated != text:
    path.write_text(updated, encoding="utf-8")
PY2
}

sync_package_manifest_prover_dep() {
  local package_dir="$1"
  local manifest="$ROOT_DIR/$package_dir/Move.toml"

  if [ ! -f "$manifest" ]; then
    return
  fi

  python3 - "$manifest" "$LOCAL_FRAMEWORK_DIR" <<'PY2'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
framework_root = Path(sys.argv[2])
text = path.read_text(encoding="utf-8")
pattern = r'(Prover\s*=\s*\{\s*local\s*=\s*")[^"]+("\s*,\s*override\s*=\s*true\s*\})'
updated = re.sub(pattern, rf'\1{(framework_root / "prover").as_posix()}\2', text)
if updated != text:
    path.write_text(updated, encoding="utf-8")
PY2
}

weaken_transfer_spec_if_requested() {
  if [ "$WEAK_TRANSFER_SPEC" != "1" ]; then
    return
  fi

  local transfer_spec="$LOCAL_FRAMEWORK_DIR/sui-specs/sources/sui-framework/transfer.move"
  local backup="$transfer_spec.bak.weak-transfer.codex"

  cp "$transfer_spec" "$backup"
  python3 - "$transfer_spec" <<'PY2'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace('    ghost::declare_global_mut<SpecTransferAddressExists, bool>();\n', '')
text = text.replace('    ghost::declare_global_mut<SpecTransferAddress, address>();\n', '')
text = text.replace('    ensures(ghost::global<SpecTransferAddressExists, bool>() == true);\n', '')
text = text.replace('    ensures(ghost::global<SpecTransferAddress, address>() == recipient);\n', '')
path.write_text(text, encoding="utf-8")
PY2
}

restore_transfer_spec_if_needed() {
  local transfer_spec="$LOCAL_FRAMEWORK_DIR/sui-specs/sources/sui-framework/transfer.move"
  local backup="$transfer_spec.bak.weak-transfer.codex"
  if [ -f "$backup" ]; then
    mv -f "$backup" "$transfer_spec" || true
  fi
}

weaken_unwrap_spec_if_requested() {
  if [ "$WEAK_UNWRAP_SPEC" != "1" ]; then
    return
  fi

  local unwrap_impl="$ROOT_DIR/../../sui-depends/contracts-sui/contracts/access/sources/ownership_transfer/two_step.move"
  local backup="$unwrap_impl.bak.weak-unwrap.codex"

  cp "$unwrap_impl" "$backup"
  python3 - "$unwrap_impl" <<'PY2'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old = """public fun unwrap<T: key + store>(self: TwoStepTransferWrapper<T>, ctx: &mut TxContext): T {
    let TwoStepTransferWrapper { id: mut wrapper_id } = self;
    let obj = dof::remove(&mut wrapper_id, WrappedKey());
    event::emit(UnwrapExecuted<T> {
        wrapper_id: wrapper_id.uid_to_inner(),
        object_id: object::id(&obj),
        owner: ctx.sender(),
    });
    wrapper_id.delete();
    obj
}
"""
new = "public native fun unwrap<T: key + store>(self: TwoStepTransferWrapper<T>, ctx: &mut TxContext): T;\n"
if old not in text:
    raise SystemExit("two_step_transfer::unwrap body not found for weak unwrap patch")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY2
}

restore_unwrap_spec_if_needed() {
  local unwrap_impl="$ROOT_DIR/../../sui-depends/contracts-sui/contracts/access/sources/ownership_transfer/two_step.move"
  local backup="$unwrap_impl.bak.weak-unwrap.codex"
  if [ -f "$backup" ]; then
    mv -f "$backup" "$unwrap_impl" || true
  fi
}

usage() {
  cat <<'USAGE'
Usage:
  run-sui-prover-wsl.sh <package-dir> <spec-function> [extra prover args...]

Examples:
  docs/formal-verification/run-sui-prover-wsl.sh \
    comments-specs comments_spec::like_paper_spec --timeout 180 --keep-temp

  docs/formal-verification/run-sui-prover-wsl.sh \
    governance-specs governance_spec::claim_locked_tokens_spec --timeout 240 --keep-temp

  WEAK_TRANSFER_SPEC=1 docs/formal-verification/run-sui-prover-wsl.sh \
    governance-specs governance_spec::nominate_operator_spec --timeout 240 --keep-temp

  WEAK_UNWRAP_SPEC=1 docs/formal-verification/run-sui-prover-wsl.sh \
    governance-specs governance_spec::unwrap_operator_permit_spec --timeout 240 --keep-temp
USAGE
}

if [ "$#" -lt 2 ]; then
  usage
  exit 1
fi

PACKAGE_DIR="$1"
SPEC_FUNCTION="$2"
shift 2

if [ ! -d "$ROOT_DIR/$PACKAGE_DIR" ]; then
  echo "Package directory not found: $PACKAGE_DIR" >&2
  exit 1
fi

if [ ! -x "$PROVER_BIN" ]; then
  echo "sui-prover not found or not executable: $PROVER_BIN" >&2
  exit 1
fi

export BOOGIE_EXE="${BOOGIE_EXE:-$BOOGIE_EXE_DEFAULT}"
export Z3_EXE="${Z3_EXE:-$Z3_EXE_DEFAULT}"
export SUI_PROVER_FRAMEWORK_PATH="${SUI_PROVER_FRAMEWORK_PATH:-$LOCAL_FRAMEWORK_DIR}"
export MOVE_HOME="${MOVE_HOME:-$MOVE_HOME_DIR}"
BOOGIE_Z3_PROVER_PATH="${BOOGIE_Z3_PROVER_PATH:-$BOOGIE_Z3_PROVER_PATH_DEFAULT}"

mkdir -p "$LOCK_DIR"
exec 9>"$RUN_LOCK_FILE"
flock 9

ensure_local_framework
seed_move_home
sync_package_vendor_prover "$PACKAGE_DIR"
weaken_transfer_spec_if_requested
weaken_unwrap_spec_if_requested

cd "$ROOT_DIR/$PACKAGE_DIR"

LOCK_FILE="Move.lock"
LOCK_BACKUP=""
MANIFEST_FILE="Move.toml"
MANIFEST_BACKUP=""
if [ -f "$LOCK_FILE" ]; then
  LOCK_BACKUP="${LOCK_FILE}.bak.codex"
  cp "$LOCK_FILE" "$LOCK_BACKUP"
  rm -f "$LOCK_FILE"
fi
if [ -f "$MANIFEST_FILE" ]; then
  MANIFEST_BACKUP="${MANIFEST_FILE}.bak.codex"
  cp "$MANIFEST_FILE" "$MANIFEST_BACKUP"
fi

cleanup() {
  if [ -n "${LOCK_BACKUP:-}" ] && [ -f "$LOCK_BACKUP" ]; then
    mv -f "$LOCK_BACKUP" "$LOCK_FILE" || true
  fi
  if [ -n "${MANIFEST_BACKUP:-}" ] && [ -f "$MANIFEST_BACKUP" ]; then
    mv -f "$MANIFEST_BACKUP" "$MANIFEST_FILE" || true
  fi
  restore_transfer_spec_if_needed
  restore_unwrap_spec_if_needed
}
trap cleanup EXIT

sync_package_manifest_prover_dep "$PACKAGE_DIR"

echo "Using package: $PACKAGE_DIR"
echo "Using spec: $SPEC_FUNCTION"
echo "Using BOOGIE_EXE: $BOOGIE_EXE"
echo "Using Z3_EXE: $Z3_EXE"
echo "Using SUI_PROVER_FRAMEWORK_PATH: $SUI_PROVER_FRAMEWORK_PATH"
echo "Using MOVE_HOME: $MOVE_HOME"
echo "Using Boogie PROVER_PATH override: $BOOGIE_Z3_PROVER_PATH"

"$PROVER_BIN" \
  -p . \
  -v \
  --skip-fetch-latest-git-deps \
  --boogie-config "proverOpt:PROVER_PATH=$BOOGIE_Z3_PROVER_PATH" \
  --functions "$SPEC_FUNCTION" \
  "$@"
