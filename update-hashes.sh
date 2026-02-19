#!/usr/bin/env bash
set -euo pipefail

# Script to fetch and update hashes for Noir and Barretenberg packages
# This script extracts versions from flake.nix and generates hashes.nix

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_FILE="$SCRIPT_DIR/flake.nix"
OUTPUT_FILE="$SCRIPT_DIR/hashes.nix"
TEMP_DIR=$(mktemp -d)
JOBS_FILE="$TEMP_DIR/jobs"

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

  echo "Found ${#noir_versions[@]} Noir versions: ${noir_versions[*]}" >&2
  echo "Found ${#bb_versions[@]} Barretenberg versions: ${bb_versions[*]}" >&2
  echo "" >&2

  # Initialize status file
  > "$JOBS_FILE.status"

  # Platforms to check
  platforms=("x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin")

  # Calculate total jobs
  TOTAL=$(( ${#noir_versions[@]} * ${#platforms[@]} + ${#bb_versions[@]} * ${#platforms[@]} ))

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
