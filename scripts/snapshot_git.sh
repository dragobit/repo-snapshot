#!/usr/bin/env bash
# git source implementation for snapshot.sh.
# Clones SOURCE_URL (shallow) into SNAPSHOT_WORK_DIR and writes
# SNAPSHOT_WORK_DIR/.snapshot-meta.env with SNAPSHOT_REVISION and
# SNAPSHOT_TIMESTAMP.

snapshot_type() {
  local clone_dir
  clone_dir="$(mktemp -d)/repo"

  local -a args=(clone "--depth=${SOURCE_DEPTH:-1}")
  if [ -n "${SOURCE_REF:-}" ]; then
    args+=(--branch "$SOURCE_REF")
  fi
  args+=("$SOURCE_URL" "$clone_dir")

  git "${args[@]}"

  local revision timestamp
  revision="$(git -C "$clone_dir" rev-parse HEAD)"
  timestamp="$(date -u '+%Y-%m-%d %H:%M:%S')"

  cp -a "$clone_dir"/. "$SNAPSHOT_WORK_DIR"/
  rm -rf "$clone_dir"

  printf "SNAPSHOT_REVISION='%s'\nSNAPSHOT_TIMESTAMP='%s'\n" \
    "$revision" "$timestamp" > "$SNAPSHOT_WORK_DIR/.snapshot-meta.env"
}
