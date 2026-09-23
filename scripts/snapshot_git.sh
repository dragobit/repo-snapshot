#!/usr/bin/env bash
# git source implementation for snapshot.sh.
#
# Fetches SOURCE_URL (shallow) into SNAPSHOT_WORK_DIR and writes
# SNAPSHOT_WORK_DIR/.snapshot-meta.env with:
#   SNAPSHOT_REVISION  - resolved commit SHA
#   SNAPSHOT_TIMESTAMP - UTC time of the snapshot
#   SNAPSHOT_TAGS      - comma-separated tags pointing exactly at the revision
#   SNAPSHOT_DESCRIBE  - git describe output, e.g. "v1.2-34-gabc123" (nearest
#                        ancestor tag + commits since), best-effort

# git is preinstalled on the runner; nothing to install.
snapshot_install() { :; }

snapshot_type() {
  local clone_dir depth
  clone_dir="$(mktemp -d)/repo"
  depth="${SOURCE_DEPTH:-1}"

  if [[ "${SOURCE_REF:-}" =~ ^[0-9a-fA-F]{40}$ ]]; then
    # A bare commit SHA cannot be passed via --branch; fetch it directly.
    mkdir -p "$clone_dir"
    git -C "$clone_dir" init -q
    git -C "$clone_dir" remote add origin "$SOURCE_URL"
    git -C "$clone_dir" fetch -q --depth="$depth" origin "$SOURCE_REF"
    git -C "$clone_dir" checkout -q FETCH_HEAD
  else
    local -a args=(clone "--depth=$depth")
    if [ -n "${SOURCE_REF:-}" ]; then
      args+=(--branch "$SOURCE_REF")
    fi
    args+=("$SOURCE_URL" "$clone_dir")
    git "${args[@]}"
  fi

  local revision timestamp tags describe
  revision="$(git -C "$clone_dir" rev-parse HEAD)"
  timestamp="$(date -u '+%Y-%m-%d %H:%M:%S')"

  # Tags pointing exactly at the snapshot revision (no history needed):
  # match both direct tag objects and peeled ^{} commit lines.
  tags="$(git ls-remote --tags "$SOURCE_URL" \
        | awk -v sha="$revision" '$1 == sha {print $2}' \
        | sed -e 's#refs/tags/##' -e 's/\^{}//' \
        | sort -u | paste -sd', ' - || true)"

  # Nearest ancestor tag ("between tag X and here"). Needs history, so deepen
  # best-effort; with --single-branch clones --deepen fetches the same branch.
  describe=""
  if git -C "$clone_dir" fetch -q --deepen=200 --tags origin 2>/dev/null; then
    describe="$(git -C "$clone_dir" describe --tags HEAD 2>/dev/null || true)"
  fi

  cp -a "$clone_dir"/. "$SNAPSHOT_WORK_DIR"/
  rm -rf "$clone_dir"

  {
    printf "SNAPSHOT_REVISION='%s'\n" "$revision"
    printf "SNAPSHOT_TIMESTAMP='%s'\n" "$timestamp"
    printf "SNAPSHOT_TAGS='%s'\n" "$tags"
    printf "SNAPSHOT_DESCRIBE='%s'\n" "$describe"
  } > "$SNAPSHOT_WORK_DIR/.snapshot-meta.env"
}
