#!/usr/bin/env bash
# Snapshot dispatcher.
#
# Required env: SOURCE_URL
# Optional env: SOURCE_TYPE (auto|git|...), SOURCE_REF, SOURCE_DEPTH
#
# To add a new source type, create scripts/snapshot_<type>.sh that defines a
# `snapshot_type` function which writes the snapshot files into
# "$SNAPSHOT_WORK_DIR" and writes revision metadata to
# "$SNAPSHOT_WORK_DIR/.snapshot-meta.env" (see snapshot_git.sh). Then add the
# type to the workflow's source_type options and to README.md.
set -euo pipefail

: "${SOURCE_URL:?SOURCE_URL is required}"
SOURCE_TYPE="${SOURCE_TYPE:-auto}"

export SNAPSHOT_WORK_DIR
SNAPSHOT_WORK_DIR="$(mktemp -d)"

if [ "$SOURCE_TYPE" = "auto" ]; then
  # Everything reachable is currently treated as git. When other VCS support
  # lands, detection rules go here.
  SOURCE_TYPE="git"
fi

case "$SOURCE_TYPE" in
  git)
    # shellcheck source=snapshot_git.sh
    . "$(dirname "$0")/snapshot_git.sh"
    ;;
  # Planned: hg | svn | fossil | archive — add a snapshot_<type>.sh and a case here.
  *)
    echo "::error::Unsupported source type: ${SOURCE_TYPE}. See README.md for supported sources."
    exit 1
    ;;
esac

snapshot_type

# Replace this repository's contents with the snapshot, keeping the snapshot
# machinery (.git, .github, scripts/). The target's own .github directory is
# NOT copied so a snapshot can never import foreign CI/CD workflows.
find . -mindepth 1 -maxdepth 1 \
  ! -name '.git' \
  ! -name '.github' \
  ! -name 'scripts' \
  -exec rm -rf {} +

rsync -a --exclude='.git' --exclude='.github' --exclude='.snapshot-meta.env' "$SNAPSHOT_WORK_DIR"/ ./

# Generate the snapshot README with provenance metadata.
REPO_NAME="${GITHUB_REPOSITORY##*/}"
REPO_NAME="${REPO_NAME:-repo}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-unknown/repo}/actions/runs/${GITHUB_RUN_ID:-0}"
# shellcheck source=/dev/null
. "$SNAPSHOT_WORK_DIR/.snapshot-meta.env"

cat > README.md <<EOF
# ${REPO_NAME}

Snapshot of [\`${SOURCE_URL}\`](${SOURCE_URL}).

| | |
|---|---|
| Source | ${SOURCE_URL} |
| Source type | ${SOURCE_TYPE} |
| Ref | ${SOURCE_REF:-default branch} |
| Revision | \`${SNAPSHOT_REVISION:-unknown}\` |
| Taken at (UTC) | ${SNAPSHOT_TIMESTAMP:-unknown} |
| Taken by | [workflow run](${RUN_URL}) |

This repository is a read-only point-in-time copy; upstream history is not
included (shallow snapshot). The source repository's own \`.github/\` directory
is excluded so its CI/CD workflows are not imported.

Re-snapshot: run the **Snapshot a repository** workflow (Actions tab) with a
new URL/ref.
EOF

rm -rf "$SNAPSHOT_WORK_DIR"
echo "Snapshot written."
