#!/usr/bin/env bash
# Snapshot dispatcher.
#
# Required env: SOURCE_URL
# Optional env: SOURCE_TYPE (auto|git|...), SOURCE_REF, SOURCE_DEPTH
#
# Source-type plugin contract — to add a new VCS/source:
#   1. Create scripts/snapshot_<type>.sh defining:
#      - snapshot_install()  (optional) install the tools this type needs,
#                            e.g. `sudo apt-get install -y mercurial`.
#      - snapshot_type()     fetch the source tree into "$SNAPSHOT_WORK_DIR"
#                            and write "$SNAPSHOT_WORK_DIR/.snapshot-meta.env"
#                            (SNAPSHOT_REVISION, SNAPSHOT_TIMESTAMP, plus any
#                            type-specific keys such as SNAPSHOT_TAGS,
#                            SNAPSHOT_DESCRIBE). See snapshot_git.sh.
#   2. Add a `case` arm below mapping the type to its file.
#   3. Extend detect_source_type() so `auto` can route to it.
#   4. Add the type to the workflow's source_type options and README.md.
set -euo pipefail

: "${SOURCE_URL:?SOURCE_URL is required}"
SOURCE_TYPE="${SOURCE_TYPE:-auto}"

export SNAPSHOT_WORK_DIR
SNAPSHOT_WORK_DIR="$(mktemp -d)"

# ---------------------------------------------------------------------------
# Source type detection. Extend this table as new types are implemented.
# First matching rule wins.
# ---------------------------------------------------------------------------
detect_source_type() {
  local url="$1"
  case "$url" in
    # Explicit VCS markers in the URL
    *hg.mozilla.org*|*hg.sr.ht*|*.hg|*/hg/*) echo hg ;;
    *svn.apache.org*|*svn.*|*/svn/*) echo svn ;;
    *.fossil|*chiselapp.com*|*/fossil/*) echo fossil ;;
    # Plain archives (not yet implemented — placeholder for the contract)
    *.tar.gz|*.tgz|*.tar.bz2|*.tbz2|*.tar.xz|*.txz|*.zip) echo archive ;;
    # Known git hosts and git suffix / protocol
    *.git|git://*|git@*|*github.com*|*gitlab.com*|*bitbucket.org*|*codeberg.org*|*git.sr.ht*|*gitea.*|*git.*/[!/]*) echo git ;;
    # Fallback: try git, which also covers self-hosted https remotes
    *) echo git ;;
  esac
}

if [ "$SOURCE_TYPE" = "auto" ]; then
  SOURCE_TYPE="$(detect_source_type "$SOURCE_URL")"
  echo "Detected source type: ${SOURCE_TYPE}"
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

# Install the tools the selected source type needs, if it declares any.
if declare -F snapshot_install >/dev/null; then
  snapshot_install
fi

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

meta_row() {
  # $1 = label, $2 = value (empty → skip)
  if [ -n "${2:-}" ]; then printf '| %s | %s |\n' "$1" "$2"; fi
}

{
  cat <<EOF
# ${REPO_NAME}

Snapshot of [\`${SOURCE_URL}\`](${SOURCE_URL}).

| | |
|---|---|
EOF
  meta_row "Source" "$SOURCE_URL"
  meta_row "Source type" "$SOURCE_TYPE"
  meta_row "Ref" "${SOURCE_REF:-default branch}"
  meta_row "Revision" "\`${SNAPSHOT_REVISION:-unknown}\`"
  meta_row "Tags at revision" "${SNAPSHOT_TAGS:-}"
  meta_row "Nearest ancestor tag" "${SNAPSHOT_DESCRIBE:-}"
  meta_row "Taken at (UTC)" "${SNAPSHOT_TIMESTAMP:-unknown}"
  meta_row "Taken by" "[workflow run](${RUN_URL})"
  cat <<EOF

This repository is a read-only point-in-time copy; upstream history is not
included (shallow snapshot). The source repository's own \`.github/\` directory
is excluded so its CI/CD workflows are not imported.

Re-snapshot: run the **Snapshot a repository** workflow (Actions tab) with a
new URL/ref.
EOF
} > README.md

rm -rf "$SNAPSHOT_WORK_DIR"
echo "Snapshot written."
