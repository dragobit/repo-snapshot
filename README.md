# repo-snapshot

Template repository that turns a new GitHub repository into a **point-in-time
snapshot** (shallow copy, no history) of any other repository — driven by a
GitHub Actions run.

## How it works

1. Click **Use this template** → create your new repository.
2. In the new repo, go to **Actions → Snapshot a repository → Run workflow**
   and fill in:
   - `source_url` — URL of the repository to snapshot
   - `ref` — optional branch/tag/commit (default: the remote HEAD)
   - `depth` — clone depth (default `1`)
3. The workflow clones the source, replaces this repo's contents with the
   source tree, rewrites `README.md` with provenance metadata (source URL,
   revision, UTC timestamp, new repo name, link to the run), and pushes the
   result as a single commit.

The source repo's own `.github/` directory is **not** imported, so a snapshot
can never pull in foreign CI/CD workflows. The snapshot machinery
(`scripts/`, `snapshot.yml`) is kept so you can re-snapshot at any time.

## Supported sources

| Source | Status | Auto-detected from URL? | Notes |
|---|---|---|---|
| Git (GitHub, GitLab, Bitbucket, Codeberg, Gitea/Forgejo, SourceHut, self-hosted `https://` or `git@`) | ✅ Supported | Yes (`.git` suffix, `git://`/`git@` schemes, known hosts; fallback default) | Public repos out of the box; private repos need credentials — see below |
| Mercurial (hg) | 🚧 Planned | Detection ready (`hg.*`, `/hg/`, `.hg`) | Add `scripts/snapshot_hg.sh` + a `source_type` option |
| Subversion (svn) | 🚧 Planned | Detection ready (`svn.*`, `/svn/`) | Same extension point |
| Fossil | 🚧 Planned | Detection ready (`.fossil`, chiselapp) | Same extension point |
| Plain tarball/zip archive URL | 🚧 Planned | Detection ready (`.tar.gz`, `.zip`, …) | Same extension point |

`source_type: auto` inspects the URL (`detect_source_type` in
`scripts/snapshot.sh`) and routes to the matching implementation. Each type
can declare a `snapshot_install()` hook that installs the tools it needs
(e.g. `apt-get install mercurial`), so per-source dependencies land only when
that source type is actually used.

## Recorded provenance

The generated README records:

- the resolved **commit SHA** (even on a shallow copy),
- **tags pointing exactly at that revision** (e.g. `v4.1.1`),
- the **nearest ancestor tag** via `git describe` (e.g. `v7-1-gf548e57` = 1
  commit after `v7`; best-effort, needs fetched history),
- source URL, requested ref, UTC timestamp, and a link to the workflow run.

## Private repositories

Pass a credential-bearing URL, e.g.
`https://<token>@github.com/owner/private-repo.git` (treat the workflow inputs
as sensitive — anyone with repo access can see dispatch inputs; prefer a
read-only, single-repo PAT or a GitHub App installation token injected via
secrets — for fully private-source support, extend the workflow to read the
token from `secrets.`).

## Extending to a new source type

1. Create `scripts/snapshot_<type>.sh` defining:
   - `snapshot_install()` (optional) — install the tools the type needs
     (e.g. `sudo apt-get install -y mercurial`). Called only when this type
     is selected.
   - `snapshot_type()` — write the source tree into `$SNAPSHOT_WORK_DIR` and
     write `$SNAPSHOT_WORK_DIR/.snapshot-meta.env`
     (`SNAPSHOT_REVISION`, `SNAPSHOT_TIMESTAMP`, plus type-specific keys like
     `SNAPSHOT_TAGS`, `SNAPSHOT_DESCRIBE` — any `SNAPSHOT_*` key may be added
     as a README row via `meta_row` in `scripts/snapshot.sh`).
   See `scripts/snapshot_git.sh`.
2. Add a `case` arm in `scripts/snapshot.sh` and a `source_type` option in
   `.github/workflows/snapshot.yml`.
3. Extend `detect_source_type` so `auto` can route to it.
4. Update the "Supported sources" table above.
