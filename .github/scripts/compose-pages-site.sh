#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:?output directory is required}"
PRODUCTION_DIR="${2:?production build directory is required}"
CURRENT_PREVIEW_DIR="${3:-}"
CURRENT_PR_NUMBER="${4:-}"
CURRENT_PREVIEW_SHA="${CURRENT_PREVIEW_SHA:-}"

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -a "$PRODUCTION_DIR/." "$OUTPUT_DIR/"

test -s "$OUTPUT_DIR/index.html"
test -s "$OUTPUT_DIR/index.wasm"

echo "Restoring previews for open same-repository pull requests."
while IFS=$'\t' read -r pr_number head_sha head_repo; do
  if [ -z "$pr_number" ] || [ -z "$head_sha" ] || [ -z "$head_repo" ]; then
    continue
  fi
  if [ "$head_repo" != "$GITHUB_REPOSITORY" ]; then
    echo "Skipping PR #${pr_number}: preview deploys are limited to branches from ${GITHUB_REPOSITORY}."
    continue
  fi
  if [ -n "$CURRENT_PR_NUMBER" ] && [ "$pr_number" = "$CURRENT_PR_NUMBER" ]; then
    continue
  fi

  run_id="$(gh api \
    "repos/${GITHUB_REPOSITORY}/actions/workflows/web.yml/runs?event=pull_request&head_sha=${head_sha}&status=success&per_page=1" \
    --jq '.workflow_runs[0].id // empty' 2>/dev/null || true)"

  if [ -z "$run_id" ]; then
    echo "::warning::No successful Web workflow artifact found for open PR #${pr_number} at ${head_sha}; skipping its preview for this deployment."
    continue
  fi

  preview_dir="$OUTPUT_DIR/pr-${pr_number}"
  rm -rf "$preview_dir"
  mkdir -p "$preview_dir"
  if ! gh run download "$run_id" \
    --repo "$GITHUB_REPOSITORY" \
    --name digigame-web-build \
    --dir "$preview_dir"; then
    rm -rf "$preview_dir"
    echo "::warning::Could not restore the Web artifact for PR #${pr_number} from run ${run_id}; its artifact may have expired."
    continue
  fi

  cat > "$preview_dir/preview-build.txt" <<EOF
DigiGame pull request preview
PR: #${pr_number}
Commit: ${head_sha}
Restored from workflow run: ${run_id}
Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
EOF

  test -s "$preview_dir/index.html"
  test -s "$preview_dir/index.wasm"
  echo "Restored PR #${pr_number} from workflow run ${run_id}."
done < <(
  gh api \
    --paginate \
    "repos/${GITHUB_REPOSITORY}/pulls?state=open&per_page=100" \
    --jq '.[] | [.number, .head.sha, .head.repo.full_name] | @tsv'
)

if [ -n "$CURRENT_PR_NUMBER" ]; then
  if [ -z "$CURRENT_PREVIEW_DIR" ] || [ ! -d "$CURRENT_PREVIEW_DIR" ]; then
    echo "Current PR preview directory is missing: ${CURRENT_PREVIEW_DIR}" >&2
    exit 1
  fi

  preview_dir="$OUTPUT_DIR/pr-${CURRENT_PR_NUMBER}"
  rm -rf "$preview_dir"
  mkdir -p "$preview_dir"
  cp -a "$CURRENT_PREVIEW_DIR/." "$preview_dir/"

  cat > "$preview_dir/preview-build.txt" <<EOF
DigiGame pull request preview
PR: #${CURRENT_PR_NUMBER}
Commit: ${CURRENT_PREVIEW_SHA:-unknown}
Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
EOF

  test -s "$preview_dir/index.html"
  test -s "$preview_dir/index.wasm"
  echo "Added current PR #${CURRENT_PR_NUMBER} preview."
fi

echo "Pages site contains:"
find "$OUTPUT_DIR" -maxdepth 1 -mindepth 1 -type d -name 'pr-*' -printf '%f\n' | sort -V
