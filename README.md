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

| Source | Status | Notes |
|---|---|---|
| Git (GitHub, GitLab, Bitbucket, Codeberg, Gitea/Forgejo, self-hosted `https://` or `git@`) | ✅ Supported | Public repos out of the box; private repos need credentials in the clone URL or a token — see below |
| Mercurial (hg) | 🚧 Planned | Add `scripts/snapshot_hg.sh` + a `source_type` option |
| Subversion (svn) | 🚧 Planned | Same extension point |
| Fossil | 🚧 Planned | Same extension point |
| Plain tarball/zip archive URL | 🚧 Planned | Same extension point |

`source_type: auto` currently resolves everything to git; detection rules for
other VCS will be added alongside their implementations.

## Private repositories

Pass a credential-bearing URL, e.g.
`https://<token>@github.com/owner/private-repo.git` (treat the workflow inputs
as sensitive — anyone with repo access can see dispatch inputs; prefer a
read-only, single-repo PAT or a GitHub App installation token injected via
secrets — for fully private-source support, extend the workflow to read the
token from `secrets.`).

## Extending to a new source type

1. Create `scripts/snapshot_<type>.sh` defining a `snapshot_type` function that
   writes the source tree into `$SNAPSHOT_WORK_DIR` and writes
   `$SNAPSHOT_WORK_DIR/.snapshot-meta.env` (`SNAPSHOT_REVISION`,
   `SNAPSHOT_TIMESTAMP`). See `scripts/snapshot_git.sh`.
2. Add a `case` arm in `scripts/snapshot.sh` and a `source_type` option in
   `.github/workflows/snapshot.yml`.
3. Update the "Supported sources" table above.
