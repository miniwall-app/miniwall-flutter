#!/usr/bin/env bash
# Copies the spec's template and component screens into assets/ so the sample app can present them by name (lib/templates.dart).
set -eu
cd "$(dirname "$0")/.."
# The spec: ../.spec (scripts/fetch-spec.sh) or $MINIWALL_SPEC_DIR. The open spec has ten example templates; point it at a bigger folder to sweep more.
fixtures="${MINIWALL_SPEC_DIR:-../.spec}/fixtures"
[ -d "$fixtures/templates" ] || { echo "The Miniwall spec is not at $fixtures: run scripts/fetch-spec.sh" >&2; exit 1; }
cp "$fixtures"/templates/*.json assets/templates/
cp "$fixtures"/components/*.json assets/components/
echo "synced $(ls assets/templates/*.json | wc -l | tr -d ' ') templates, $(ls assets/components/*.json | wc -l | tr -d ' ') components"
