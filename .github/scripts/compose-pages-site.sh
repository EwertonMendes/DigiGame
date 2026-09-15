#!/usr/bin/env bash
set -euo pipefail

OUTPUT_DIR="${1:?output directory is required}"
PRODUCTION_DIR="${2:?production build directory is required}"
CURRENT_PREVIEW_DIR="${3:-}"
CURRENT_PR_NUMBER="${4:-}"
CURRENT_PREVIEW_SHA="${CURRENT_PREVIEW_SHA:-}"

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GH_TOKEN:?GH_TOKEN is required}"

find_validated_run() {
  local head_sha="$1"
  local run_id
  local jobs_json
  local integrated_total
  local integrated_success
  local legacy_total
  local legacy_success
  local browser_regression_total
  local fast_gate_success

  while IFS= read -r run_id; do
    if [ -z "$run_id" ]; then
      continue
    fi

    jobs_json="$(gh api \
      "repos/${GITHUB_REPOSITORY}/actions/runs/${run_id}/jobs?filter=latest&per_page=100" \
      2>/dev/null || printf '%s' '{"jobs":[]}')"

    # Current pipeline: one fast build gate followed by the three browser suites
    # in parallel inside DigiGame Web.
    integrated_total="$(jq '[.jobs[] | select(
      .name == "Fast Web gate" or
      .name == "Browser regression · desktop" or
      .name == "Browser regression · combat-vfx" or
      .name == "Browser regression · mobile"
    )] | unique_by(.name) | length' <<<"$jobs_json")"
    integrated_success="$(jq '[.jobs[] | select(
      (.name == "Fast Web gate" or
       .name == "Browser regression · desktop" or
       .name == "Browser regression · combat-vfx" or
       .name == "Browser regression · mobile") and
      .conclusion == "success"
    )] | unique_by(.name) | length' <<<"$jobs_json")"

    if [ "$integrated_total" = "4" ] && [ "$integrated_success" = "4" ]; then
      printf '%s\n' "$run_id"
      return 0
    fi

    # Compatibility with the older all-in-one browser workflow used before the
    # fast-gate/post-Web split. Keeping this allows existing open PR previews to
    # survive the CI migration without forcing commits onto their branches.
    legacy_total="$(jq '[.jobs[] | select(
      .name == "Validate and build Web" or
      .name == "Browser smoke · desktop" or
      .name == "Browser smoke · combat" or
      .name == "Browser smoke · mobile" or
      .name == "Browser smoke · vfx"
    )] | unique_by(.name) | length' <<<"$jobs_json")"
    legacy_success="$(jq '[.jobs[] | select(
      (.name == "Validate and build Web" or
       .name == "Browser smoke · desktop" or
       .name == "Browser smoke · combat" or
       .name == "Browser smoke · mobile" or
       .name == "Browser smoke · vfx") and
      .conclusion == "success"
    )] | unique_by(.name) | length' <<<"$jobs_json")"

    if [ "$legacy_total" = "5" ] && [ "$legacy_success" = "5" ]; then
      printf '%s\n' "$run_id"
      return 0
    fi

    # Rollout compatibility for the short-lived split architecture where Web
    # contained only Fast Web gate and browser QA lived in post-web.yml. Preview
    # deployment in that architecture depended on the successful Web gate, so
    # preserving those artifacts matches the behavior users already had.
    browser_regression_total="$(jq '[.jobs[] | select(.name | startswith("Browser regression · "))] | length' <<<"$jobs_json")"
    fast_gate_success="$(jq '[.jobs[] | select(.name == "Fast Web gate" and .conclusion == "success")] | length' <<<"$jobs_json")"

    if [ "$browser_regression_total" = "0" ] && [ "$fast_gate_success" -ge 1 ]; then
      printf '%s\n' "$run_id"
      return 0
    fi
  done < <(
    gh api \
      "repos/${GITHUB_REPOSITORY}/actions/workflows/web.yml/runs?event=pull_request&head_sha=${head_sha}&per_page=10" \
      --jq '.workflow_runs[].id' \
      2>/dev/null || true
  )

  return 1
}

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

  run_id="$(find_validated_run "$head_sha" || true)"
  if [ -z "$run_id" ]; then
    echo "::warning::No validated Web workflow was found for open PR #${pr_number} at ${head_sha}; skipping its preview for this deployment."
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
    echo "::warning::Could not restore the Web artifact for PR #${pr_number} from validated run ${run_id}; its artifact may have expired."
    continue
  fi

  cat > "$preview_dir/preview-build.txt" <<EOF
DigiGame pull request preview
PR: #${pr_number}
Commit: ${head_sha}
Restored from validated workflow run: ${run_id}
Generated: $(date -u +'%Y-%m-%dT%H:%M:%SZ')
EOF

  test -s "$preview_dir/index.html"
  test -s "$preview_dir/index.wasm"
  echo "Restored PR #${pr_number} from validated workflow run ${run_id}."
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
