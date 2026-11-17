#!/usr/bin/env bash
# Usage: select-builds.sh <matrix.json> [changed-files.txt] [base-matrix.json]
# Env: TARGET, DISTRIBUTION, VERSION (empty or "all" = no filter), REPUBLISH_RUN_ID.
# Prints builds=, dependent_builds=, releases= and publish= JSON lines for $GITHUB_OUTPUT.
set -euo pipefail

matrix="$1"
changed="${2:-}"
base_matrix="${3:-}"

selected="$(jq -c \
  --arg target "${TARGET:-all}" \
  --arg dist "${DISTRIBUTION:-all}" \
  --arg version "${VERSION:-all}" \
  '[.[] | select(
      ($target == "all" or $target == "" or .target == $target) and
      ($dist == "all" or $dist == "" or .distribution == $dist) and
      ($version == "all" or $version == "" or .version == $version)
    )]' "$matrix")"

if [[ -n "$changed" ]]; then
  ids=()
  while IFS= read -r entry; do
    id="$(jq -r '"\(.target)-\(.distribution)-\(.version)"' <<<"$entry")"
    hit=false
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      if [[ "$file" == ".github/workflows/build.yaml" || "$file" == ".github/workflows/build-one.yaml" || "$file" == ".github/scripts/select-builds.sh" ]]; then
        [[ "$id" == "cuda-mocks-ubuntu22.04-0.0.1" ]] && hit=true
      fi
      while IFS= read -r pattern; do
        # shellcheck disable=SC2053 # pattern is a glob from build-matrix.json
        [[ "$file" == $pattern ]] && hit=true
      done < <(jq -r '.paths[]' <<<"$entry")
    done <"$changed"
    if [[ "$hit" == false ]] && grep -qx '.github/build-matrix.json' "$changed"; then
      if [[ -z "$base_matrix" ]] || ! jq -e --argjson e "$entry" 'any(.[]; . == $e)' "$base_matrix" >/dev/null; then
        hit=true
      fi
    fi
    if [[ "$hit" == true ]]; then
      ids+=("$id")
    fi
  done < <(jq -c '.[]' <<<"$selected")
  while IFS= read -r dependent; do
    ids+=("$dependent")
  done < <(jq -r --args '.[] | select(.requires and (.requires as $r | $ARGS.positional | index($r))) | "\(.target)-\(.distribution)-\(.version)"' ${ids[@]+"${ids[@]}"} <<<"$selected")
  selected="$(jq -c --args '[.[] | select("\(.target)-\(.distribution)-\(.version)" as $id | $ARGS.positional | index($id))]' ${ids[@]+"${ids[@]}"} <<<"$selected")"
fi

per_arch="$(jq -c '
  def arches: {
    amd64: {
      runner: "ubuntu-24.04",
      platform: "linux/amd64",
      uname: "x86_64",
      ld_library_path: "/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/targets/x86_64-linux/lib",
      nccl_ld_library_path: "/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib:/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/usr/local/nvidia/lib:/usr/local/nvidia/lib64:/usr/local/cuda/targets/x86_64-linux/lib"
    },
    arm64: {
      runner: "ubuntu-24.04-arm",
      platform: "linux/arm64",
      uname: "aarch64",
      ld_library_path: "/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib:/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/nvidia/lib:/usr/local/cuda-12.9/targets/sbsa-linux/lib/",
      nccl_ld_library_path: "/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib:/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/nvidia/lib:/usr/local/cuda-12.9/targets/sbsa-linux/lib/:/usr/mpi/gcc/openmpi-${OPENMPI_VERSION}/lib"
    }
  };
  def fill($a): reduce ($a | to_entries[]) as $kv (.; split("{\($kv.key)}") | join($kv.value));
  [.[] as $e
   | ($e.arches // ["amd64", "arm64"])[] as $arch
   | arches[$arch] as $a
   | {
       id: "\($e.target)-\($e.distribution)-\($e.version)",
       distribution: $e.distribution,
       version: $e.version,
       requires: ($e.requires // ""),
       arch: $arch,
       artifact: "\($e.target)-\($e.distribution)-\($e.version)-\($arch)",
       runner: $a.runner,
       platform: $a.platform,
       dockerfile: $e.dockerfile,
       build_args: ($e.build_args | map(fill($a)) | join("\n")),
       output: ($e.output | fill($a)),
       files: $e.files,
       publish: ($e.publish // false)
     }]' <<<"$selected")"

releases="$(jq -c '[.[] | {
    id: "\(.target)-\(.distribution)-\(.version)",
    files,
    tag: .release_tag,
    name: .release_name,
    body: (.release_body // "")
  }]' <<<"$selected")"

publish="$(jq -c '[.[] | select(.publish) | {artifact}]' <<<"$per_arch")"

if [[ -n "${REPUBLISH_RUN_ID:-}" ]]; then
  echo "builds=[]"
  echo "dependent_builds=[]"
  echo "releases=[]"
else
  echo "builds=$(jq -c 'map(select(.requires == "") | del(.publish))' <<<"$per_arch")"
  echo "dependent_builds=$(jq -c 'map(select(.requires != "") | del(.publish))' <<<"$per_arch")"
  echo "releases=$releases"
fi
echo "publish=$publish"
