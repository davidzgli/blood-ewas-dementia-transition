#!/usr/bin/env bash
# setup_data_links.sh - link the restricted data tiers into data/
#
# This repository ships only data/publicly_available/. The four restricted tiers
# are yours to populate, either by
#   (a) copying approved files into data/<tier>/, or
#   (b) symlinking data/<tier> at a directory you already hold -- what this does.
#
# Usage:
#   bash manage_project/setup_data_links.sh <source-data-dir>
#   bash manage_project/setup_data_links.sh --status
#   bash manage_project/setup_data_links.sh --unlink
#
# Idempotent. Never touches data/publicly_available/ (real, committed files) and
# refuses to replace a non-empty real directory. Every link it creates is
# gitignored. Run from the project root.
#
# IMPORTANT: pointing this at one directory does not guarantee a self-contained
# tree -- the source may itself contain symlinks that escape elsewhere. Check
# with:  find -L data -type l -print

set -euo pipefail

# publicly_available is deliberately absent: it holds real committed files, so it
# must be unreachable by this script rather than guarded by a runtime check.
TIERS=(collaborator_only private published_data upon_request)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[[ -f _quarto.yml ]] || die "run from the project root (where _quarto.yml is)"

mode=link
case "${1:-}" in
  --status)  mode=status ;;
  --unlink)  mode=unlink ;;
  -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
  -*)        die "unknown option: $1" ;;
  "")        die "missing <source-data-dir>; try --help" ;;
esac

if [[ $mode == link ]]; then
  [[ -d "$1" ]] || die "source data dir not found: $1"
  src=$(cd "$1" && pwd -P)                    # absolute and resolved
fi

mkdir -p data

for tier in "${TIERS[@]}"; do
  target="data/$tier"

  case $mode in
    status)
      if [[ -L $target ]]; then
        printf '%-18s symlink -> %s%s\n' "$tier" "$(readlink "$target")" \
               "$( [[ -e $target ]] || printf '   [BROKEN]' )"
      elif [[ -d $target ]]; then
        printf '%-18s real dir (%s entries)\n' "$tier" "$(find "$target" -mindepth 1 | wc -l)"
      else
        printf '%-18s absent\n' "$tier"
      fi
      continue ;;
    unlink)
      if [[ -L $target ]]; then
        rm "$target"; printf 'unlinked  %s\n' "$target"
      else
        printf 'skipped   %s (not a symlink)\n' "$target"
      fi
      continue ;;
  esac

  # --- link mode ---
  if [[ ! -d "$src/$tier" ]]; then
    printf 'skipped   %-28s (no %s in source)\n' "$target" "$tier"
    continue
  fi

  if [[ -L $target ]]; then
    rm "$target"                              # idempotent: replace our own link
  elif [[ -e $target ]]; then
    if [[ -d $target && -z $(ls -A "$target") ]]; then
      rmdir "$target"                         # empty placeholder
    else
      die "$target exists, is not a symlink, and is not empty -- refusing to clobber"
    fi
  fi

  ln -s "$src/$tier" "$target"
  printf 'linked    %-28s -> %s\n' "$target" "$src/$tier"
done

if [[ $mode == link ]]; then
  printf '\ndata/publicly_available/ untouched (real committed files).\n'
  printf 'Check status:    bash manage_project/setup_data_links.sh --status\n'
  printf 'Dangling links:  find -L data -type l -print\n'
fi
