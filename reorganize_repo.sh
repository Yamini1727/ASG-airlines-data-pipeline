#!/usr/bin/env bash
# Run this from the ROOT of your local clone of ASG-airlines-data-pipeline.
# It creates the proper folder structure and moves existing files into place.
# It's defensive — it only moves a file if it actually finds it

set -e

echo "Creating folder structure..."
mkdir -p data/raw docs/images notebooks powerbi

NOTEBOOK="ASG_Airlines.ipynb"
SOURCE_XLSX="UseCase - Airlines.xlsx"
DOCX="ASG_Airlines_Yamini.D.docx"
PBIX="ASG_Airlines Dashboard.pbix"


move_if_exists () {
  local src="$1"
  local dest="$2"
  if [ -f "$src" ]; then
    git mv "$src" "$dest"
    echo "moved: $src -> $dest"
  else
    echo "skipped (not found at root): $src"
  fi
}

move_if_exists "$NOTEBOOK" "notebooks/$NOTEBOOK"
move_if_exists "$SOURCE_XLSX" "data/raw/$SOURCE_XLSX"
move_if_exists "$DOCX" "docs/$DOCX"
move_if_exists "$PBIX" "powerbi/$PBIX"

echo ""
echo "Now:"
echo "1. Drop dashboard screenshots into docs/images/ (e.g. dashboard_overview.png, dashboard_duration.png)"
echo "2. Replace README.md, requirements.txt, and .gitignore at the repo root with the versions provided"
echo "3. Review 'git status' below, then commit"
echo ""
git status
