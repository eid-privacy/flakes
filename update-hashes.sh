#!/usr/bin/env bash
set -euo pipefail

# Script to fetch and update hashes for Noir and Barretenberg packages
# This script extracts versions from flake.nix and generates hashes.nix

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_FILE="$SCRIPT_DIR/flake.nix"
OUTPUT_FILE="$SCRIPT_DIR/hashes.nix"
NARGO_T256_FILE="$SCRIPT_DIR/nargo-t256.nix"
TEMP_DIR=$(mktemp -d)
JOBS_FILE="$TEMP_DIR/jobs"
FAKE_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Statistics
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# Cleanup on exit
trap "rm -rf $TEMP_DIR" EXIT

# Parse flake.nix to extract Noir versions
parse_noir_versions() {
  grep -A 0 'version = "' "$FLAKE_FILE" | \
    grep 'noir.nix' | \
    sed -E 's/.*version = "([^"]+)".*/\1/' | \
    sort -u
}

# Parse flake.nix to extract Barretenberg versions
parse_bb_versions() {
  grep -A 0 'version = "' "$FLAKE_FILE" | \
    grep 'barretenberg.nix' | \
    sed -E 's/.*version = "([^"]+)".*/\1/' | \
    sort -u
}

# Parse flake.nix to extract nargo-t256 revs (git revs/tags/commits)
parse_nargo_t256_revs() {
  grep -oE 'rev = "[^"]+"' "$FLAKE_FILE" | \
    sed -E 's/rev = "([^"]+)"/\1/' | \
    sort -u
}

# Get platform target for Noir
get_noir_target() {
  local platform=$1
  case $platform in
    x86_64-linux) echo "x86_64-unknown-linux-gnu" ;;
    aarch64-linux) echo "aarch64-unknown-linux-gnu" ;;
    x86_64-darwin) echo "x86_64-apple-darwin" ;;
    aarch64-darwin) echo "aarch64-apple-darwin" ;;
    *) echo "unknown" ;;
  esac
}

# Get platform components for Barretenberg
get_bb_platform() {
  local platform=$1
  case $platform in
    x86_64-linux) echo "amd64" "linux" ;;
    aarch64-linux) echo "arm64" "linux" ;;
    x86_64-darwin) echo "amd64" "darwin" ;;
    aarch64-darwin) echo "arm64" "darwin" ;;
    *) echo "unknown" "unknown" ;;
  esac
}

# Check if existing hash is valid (not placeholder)
is_valid_hash() {
  local hash=$1
  if [[ "$hash" == "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" ]] || \
     [[ "$hash" == *"PLACEHOLDER"* ]] || \
     [[ -z "$hash" ]]; then
    return 1
  fi
  return 0
}

# Load existing hash from hashes.nix if it exists
get_existing_hash() {
  local tool=$1
  local version=$2
  local platform=$3

  if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo ""
    return
  fi

  # Try to extract hash using nix-instantiate
  local hash
  hash=$(nix-instantiate --eval --strict --expr \
    "(import $OUTPUT_FILE).$tool.\"$version\".\"$platform\" or \"\"" 2>/dev/null | \
    tr -d '"' || echo "")

  echo "$hash"
}

# Compute hash for a URL
compute_hash() {
  local url=$1
  local tool=$2
  local version=$3
  local platform=$4
  local output_file="$TEMP_DIR/${tool}_${version}_${platform}.hash"

  # Check if we should skip (existing valid hash)
  local existing_hash
  existing_hash=$(get_existing_hash "$tool" "$version" "$platform")

  if is_valid_hash "$existing_hash"; then
    echo -e "${YELLOW}[SKIP]${NC} $tool $version $platform (hash exists)" >&2
    echo "$existing_hash" > "$output_file"
    echo "SKIPPED" >> "$JOBS_FILE.status"
    return 0
  fi

  echo -e "${GREEN}[FETCH]${NC} $tool $version $platform" >&2

  # Try to fetch and compute hash
  local hash32
  if hash32=$(nix-prefetch-url --type sha256 "$url" 2>/dev/null); then
    # Convert to SRI format
    local hash_sri
    if hash_sri=$(nix hash to-sri --type sha256 "$hash32" 2>/dev/null); then
      echo -e "${GREEN}[OK]${NC} $tool $version $platform" >&2
      echo "$hash_sri" > "$output_file"
      echo "SUCCESS" >> "$JOBS_FILE.status"
      return 0
    fi
  fi

  # Failed to fetch
  echo -e "${RED}[FAIL]${NC} $tool $version $platform (using placeholder)" >&2
  echo "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" > "$output_file"
  echo "FAILED" >> "$JOBS_FILE.status"
  return 0
}

# Fetch hash in background job
fetch_hash() {
  local tool=$1
  local version=$2
  local platform=$3
  local url=$4

  compute_hash "$url" "$tool" "$version" "$platform" &
}

# Load an existing nargo-t256 hash field (srcHash or cargoHash) from hashes.nix
get_existing_nargo_t256_hash() {
  local rev=$1
  local field=$2

  if [[ ! -f "$OUTPUT_FILE" ]]; then
    echo ""
    return
  fi

  local hash
  hash=$(nix-instantiate --eval --strict --expr \
    "(import $OUTPUT_FILE).nargo-t256.\"$rev\".\"$field\" or \"\"" 2>/dev/null | \
    tr -d '"' || echo "")

  echo "$hash"
}

# Build a Nix expression, evaluate it with a fake fixed-output hash, and scrape the
# real hash out of the resulting hash-mismatch error. This is the standard trick for
# computing FOD hashes and needs no extra prefetch tooling.
extract_real_hash_from_mismatch() {
  local expr=$1
  local out
  out=$(nix build --impure --no-link --expr "$expr" 2>&1 || true)
  echo "$out" | grep -oE 'got:[[:space:]]+sha256-[A-Za-z0-9+/=]+' | tail -1 | awk '{print $2}'
}

# Compute srcHash + cargoHash for one nargo-t256 rev
compute_nargo_t256_hashes() {
  local rev=$1
  local src_output_file="$TEMP_DIR/nargo-t256_${rev}_srcHash.hash"
  local cargo_output_file="$TEMP_DIR/nargo-t256_${rev}_cargoHash.hash"

  local existing_src existing_cargo
  existing_src=$(get_existing_nargo_t256_hash "$rev" "srcHash")
  existing_cargo=$(get_existing_nargo_t256_hash "$rev" "cargoHash")

  if is_valid_hash "$existing_src" && is_valid_hash "$existing_cargo"; then
    echo -e "${YELLOW}[SKIP]${NC} nargo-t256 $rev (hashes exist)" >&2
    echo "$existing_src" > "$src_output_file"
    echo "$existing_cargo" > "$cargo_output_file"
    echo "SKIPPED" >> "$JOBS_FILE.status"
    echo "SKIPPED" >> "$JOBS_FILE.status"
    return 0
  fi

  echo -e "${GREEN}[FETCH]${NC} nargo-t256 $rev (srcHash)" >&2
  local src_hash
  src_hash=$(extract_real_hash_from_mismatch \
    "(import <nixpkgs> {}).fetchFromGitHub { owner = \"eid-privacy\"; repo = \"noir\"; rev = \"$rev\"; hash = \"$FAKE_HASH\"; }")

  if [[ -z "$src_hash" ]]; then
    echo -e "${RED}[FAIL]${NC} nargo-t256 $rev (srcHash, using placeholder)" >&2
    echo "$FAKE_HASH" > "$src_output_file"
    echo "FAILED" >> "$JOBS_FILE.status"
    echo "FAILED" >> "$JOBS_FILE.status"
    return 0
  fi
  echo -e "${GREEN}[OK]${NC} nargo-t256 $rev (srcHash)" >&2
  echo "$src_hash" > "$src_output_file"
  echo "SUCCESS" >> "$JOBS_FILE.status"

  echo -e "${GREEN}[FETCH]${NC} nargo-t256 $rev (cargoHash)" >&2
  local cargo_hash
  cargo_hash=$(extract_real_hash_from_mismatch \
    "((import <nixpkgs> {}).callPackage $NARGO_T256_FILE { rev = \"$rev\"; srcHash = \"$src_hash\"; cargoHash = \"$FAKE_HASH\"; }).cargoDeps")

  if [[ -z "$cargo_hash" ]]; then
    echo -e "${RED}[FAIL]${NC} nargo-t256 $rev (cargoHash, using placeholder)" >&2
    echo "$FAKE_HASH" > "$cargo_output_file"
    echo "FAILED" >> "$JOBS_FILE.status"
    return 0
  fi
  echo -e "${GREEN}[OK]${NC} nargo-t256 $rev (cargoHash)" >&2
  echo "$cargo_hash" > "$cargo_output_file"
  echo "SUCCESS" >> "$JOBS_FILE.status"
}

# Fetch nargo-t256 hashes in a background job
fetch_nargo_t256_hash() {
  local rev=$1

  compute_nargo_t256_hashes "$rev" &
}

# Build the nargo-t256 section of hashes.nix from computed hashes
build_nargo_t256_hashes_file() {
  local revs=("$@")

  for rev in "${revs[@]}"; do
    local src_file="$TEMP_DIR/nargo-t256_${rev}_srcHash.hash"
    local cargo_file="$TEMP_DIR/nargo-t256_${rev}_cargoHash.hash"
    local src_hash cargo_hash
    src_hash=$([[ -f "$src_file" ]] && cat "$src_file" || echo "$FAKE_HASH")
    cargo_hash=$([[ -f "$cargo_file" ]] && cat "$cargo_file" || echo "$FAKE_HASH")

    echo "    \"${rev}\" = {"
    echo "      srcHash = \"${src_hash}\";"
    echo "      cargoHash = \"${cargo_hash}\";"
    echo "    };"
  done
}

# Build hashes.nix from computed hashes
build_hashes_file() {
  local tool=$1
  local versions=("${@:2}")
  local platforms=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin")

  for version in "${versions[@]}"; do
    echo "    \"${version}\" = {"
    for platform in "${platforms[@]}"; do
      local hash_file="$TEMP_DIR/${tool}_${version}_${platform}.hash"
      if [[ -f "$hash_file" ]]; then
        local hash
        hash=$(cat "$hash_file")
        echo "      \"${platform}\" = \"${hash}\";"
      else
        echo "      \"${platform}\" = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";"
      fi
    done
    echo "    };"
  done
}

main() {
  echo "=== Nix Flakes Hash Updater ===" >&2
  echo "" >&2

  # Parse versions from flake.nix
  echo "Parsing versions from flake.nix..." >&2
  noir_versions=()
  while IFS= read -r line; do
    noir_versions+=("$line")
  done < <(parse_noir_versions)

  bb_versions=()
  while IFS= read -r line; do
    bb_versions+=("$line")
  done < <(parse_bb_versions)

  nargo_t256_revs=()
  while IFS= read -r line; do
    nargo_t256_revs+=("$line")
  done < <(parse_nargo_t256_revs)

  echo "Found ${#noir_versions[@]} Noir versions: ${noir_versions[*]}" >&2
  echo "Found ${#bb_versions[@]} Barretenberg versions: ${bb_versions[*]}" >&2
  echo "Found ${#nargo_t256_revs[@]} nargo-t256 revs: ${nargo_t256_revs[*]}" >&2
  echo "" >&2

  # Initialize status file
  > "$JOBS_FILE.status"

  # Platforms to check
  platforms=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin")

  # Calculate total jobs
  TOTAL=$(( ${#noir_versions[@]} * ${#platforms[@]} + ${#bb_versions[@]} * ${#platforms[@]} + ${#nargo_t256_revs[@]} * 2 ))

  echo "Fetching hashes (this may take a while)..." >&2
  echo "" >&2

  # Fetch Noir hashes
  for version in "${noir_versions[@]}"; do
    for platform in "${platforms[@]}"; do
      local target
      target=$(get_noir_target "$platform")
      local url="https://github.com/noir-lang/noir/releases/download/v${version}/nargo-${target}.tar.gz"
      fetch_hash "noir" "$version" "$platform" "$url"
    done
  done

  # Fetch Barretenberg hashes
  for version in "${bb_versions[@]}"; do
    for platform in "${platforms[@]}"; do
      read -r arch plat < <(get_bb_platform "$platform")
      local url="https://github.com/AztecProtocol/aztec-packages/releases/download/v${version}/barretenberg-${arch}-${plat}.tar.gz"
      fetch_hash "barretenberg" "$version" "$platform" "$url"
    done
  done

  # Fetch nargo-t256 hashes (srcHash + cargoHash per rev)
  for rev in "${nargo_t256_revs[@]}"; do
    fetch_nargo_t256_hash "$rev"
  done

  # Wait for all background jobs
  echo "Waiting for all downloads to complete..." >&2
  wait

  # Count results
  if [[ -f "$JOBS_FILE.status" ]]; then
    SUCCESS=$(grep -c "SUCCESS" "$JOBS_FILE.status" || true)
    FAILED=$(grep -c "FAILED" "$JOBS_FILE.status" || true)
    SKIPPED=$(grep -c "SKIPPED" "$JOBS_FILE.status" || true)
  fi

  echo "" >&2
  echo "=== Building hashes.nix ===" >&2

  # Build hashes.nix
  {
    echo "# Generated by update-hashes.sh"
    echo "# Do not edit manually - run ./update-hashes.sh to update"
    echo "{"
    echo "  noir = {"
    build_hashes_file "noir" "${noir_versions[@]}"
    echo "  };"
    echo ""
    echo "  nargo-t256 = {"
    build_nargo_t256_hashes_file "${nargo_t256_revs[@]}"
    echo "  };"
    echo ""
    echo "  barretenberg = {"
    build_hashes_file "barretenberg" "${bb_versions[@]}"
    echo "  };"
    echo "}"
  } > "$OUTPUT_FILE"

  echo "" >&2
  echo "=== Summary ===" >&2
  echo -e "Total:    $TOTAL" >&2
  echo -e "${GREEN}Success:  $SUCCESS${NC}" >&2
  echo -e "${YELLOW}Skipped:  $SKIPPED${NC}" >&2
  echo -e "${RED}Failed:   $FAILED${NC}" >&2
  echo "" >&2
  echo "Generated: $OUTPUT_FILE" >&2

  if [[ $FAILED -gt 0 ]]; then
    echo "" >&2
    echo -e "${YELLOW}Warning: Some hashes failed to fetch and were set to placeholders.${NC}" >&2
    echo "These builds will fail at build time with a clear error message." >&2
  fi
}

main
