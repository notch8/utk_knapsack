# Branching and Releases

UTK Knapsack follows a [GitLab Flow](https://docs.gitlab.com/ee/topics/gitlab_flow.html) branching model with three long-lived branches that map to environments.

## Branches

| Branch | Environment | Auto-deploy |
|---|---|---|
| `main` | dev | yes |
| `staging` | staging | yes |
| `production` | production | no |

Code flows in one direction: `main` -> `staging` -> `production`. Each promotion is a merge-forward PR.

## Rules

- **Merge only.** Squash and rebase are disabled on all three branches. This keeps commit SHAs identical across branches so you can always tell whether a commit has reached a given environment. It also prevents the submodule pointer rollback problem that can occur with squash-merging.
- **Never commit directly** to `staging` or `production`. All work lands on `main` first, then gets promoted forward.
- **One approval required** on every PR.
- **Required labels.** Every PR to `main` needs one of: a semver label (`major-ver`, `minor-ver`, `patch-ver`), `dependencies`, `database-changes`, or `ignore-for-release`. The label determines the release-note category and version bump.

## Promoting code

1. Open a PR from `main` into `staging` (or `staging` into `production`).
2. Get approval and merge. Do not squash.
3. For `main` and `staging`, the merge triggers CI and on success the deploy workflow pushes to the matching environment automatically. Production is not yet wired into the deploy workflow.

## Releases

Release notes are automated with [release-drafter](https://github.com/release-drafter/release-drafter):

1. **Draft created on staging promotion.** When code is merged into `staging`, release-drafter collects all PRs since the last release and groups them by label into a draft release. The tag is created at this point.
2. **Published on production promotion.** When code is merged into `production`, the draft release is published.

UTK Knapsack maintains its own version line independent of Hyku's version. Release bodies should state which Hyku and Hyrax versions are included.

### Labels and categories

| Label | Release category | Version bump |
|---|---|---|
| `major-ver` | Breaking Changes | major |
| `minor-ver` | New Features | minor |
| `patch-ver` | Bug Fixes | patch |
| `dependencies` | Dependencies | patch |
| `database-changes` | Database Changes | patch |
| `ignore-for-release` | (excluded) | -- |

If no version label is present, the default bump is `patch`.

## Upstream

Hyku (`samvera/hyku`) follows the same branching model. See [Hyku's branching docs](https://github.com/samvera/hyku/blob/main/docs/branching-and-releases.md) for the upstream mapping.
