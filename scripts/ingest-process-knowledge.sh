#!/usr/bin/env bash
# Ingest process knowledge YAML files into Qdrant collection "process_knowledge".
#
# Parses each domain YAML, extracts individual rules/SOPs/edge-cases,
# stores each as a separate Qdrant point with metadata:
#   - domain: insurance|security|infrastructure|development|governance|operations
#   - type: rule|decision_tree|sop|edge_case
#   - status: active|deprecated|draft
#   - tags: from the YAML entry
#   - version: from the YAML entry
#   - provenance: source field from the YAML entry
#   - content: the full rule text (for embedding)
#
# Usage: ./scripts/ingest-process-knowledge.sh [--dry-run]
#
# Requires: python3, PyYAML
# Qdrant MCP tools: memory_store with project="process_knowledge"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOMAINS_DIR="$PLUGIN_ROOT/skills/process-knowledge/references/domains"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] No data will be written to Qdrant"
fi

if ! command -v python3 &>/dev/null; then
    echo "ERROR: python3 is required but not found"
    exit 1
fi

if ! python3 -c "import yaml" 2>/dev/null; then
    echo "ERROR: PyYAML is required. Install with: pip3 install pyyaml"
    exit 1
fi

if [ ! -d "$DOMAINS_DIR" ]; then
    echo "ERROR: Domains directory not found: $DOMAINS_DIR"
    exit 1
fi

TOTAL_RULES=0
TOTAL_SKIPPED=0
TOTAL_ERRORS=0

for DOMAIN_FILE in "$DOMAINS_DIR"/*.yaml; do
    [ -f "$DOMAIN_FILE" ] || continue
    DOMAIN="$(basename "$DOMAIN_FILE" .yaml)"
    echo "Processing domain: $DOMAIN"

    python3 -c "
import yaml
import json
import sys

domain = '$DOMAIN'
dry_run = $( [ "$DRY_RUN" = true ] && echo "True" || echo "False" )

with open('$DOMAIN_FILE', 'r') as f:
    data = yaml.safe_load(f)

if not data:
    print(f'  SKIP: {domain} — empty or invalid YAML')
    sys.exit(0)

count = 0
skipped = 0

for section_key in ['rules', 'decision_trees', 'sops', 'edge_cases']:
    entries = data.get(section_key, [])
    if not isinstance(entries, list):
        continue

    entry_type = section_key.rstrip('s')
    if section_key == 'edge_cases':
        entry_type = 'edge_case'
    elif section_key == 'decision_trees':
        entry_type = 'decision_tree'

    for entry in entries:
        if not isinstance(entry, dict):
            skipped += 1
            continue

        status = entry.get('status', 'active')
        if status == 'deprecated':
            skipped += 1
            continue

        entry_id = entry.get('id', entry.get('name', f'{domain}_{entry_type}_{count}'))
        content = entry.get('description', entry.get('content', entry.get('name', '')))
        if not content:
            content = json.dumps(entry, default=str)

        tags = entry.get('tags', [])
        if isinstance(tags, str):
            tags = [tags]

        version = entry.get('version', '1.0')
        provenance = entry.get('source', entry.get('provenance', 'yaml_import'))

        point = {
            'content': f'[{entry_type.upper()}] {entry_id}: {content}',
            'metadata': {
                'domain': domain,
                'type': entry_type,
                'rule_id': str(entry_id),
                'status': status,
                'version': str(version),
                'provenance': provenance,
                'tags': tags,
                'source_file': '$DOMAIN_FILE'
            }
        }

        if dry_run:
            print(f'  [DRY RUN] Would store: {entry_type} {entry_id} ({domain})')
        else:
            print(json.dumps(point))

        count += 1

print(f'  {domain}: {count} entries extracted, {skipped} skipped', file=sys.stderr)
print(f'COUNTS:{count}:{skipped}', file=sys.stderr)
" 2>"$DOMAINS_DIR/../.ingest-stderr.tmp"
    while IFS= read -r line; do
        if [[ "$line" == COUNTS:* ]]; then
            IFS=: read -r _ c s <<< "$line"
            TOTAL_RULES=$((TOTAL_RULES + c))
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + s))
        else
            echo "$line"
        fi
    done < "$DOMAINS_DIR/../.ingest-stderr.tmp"
    rm -f "$DOMAINS_DIR/../.ingest-stderr.tmp"
done

echo ""
echo "=== Ingestion Summary ==="
echo "Domains processed: $(ls "$DOMAINS_DIR"/*.yaml 2>/dev/null | wc -l | tr -d ' ')"
echo "Total rules extracted: $TOTAL_RULES"
echo "Total skipped (deprecated): $TOTAL_SKIPPED"
echo "Total errors: $TOTAL_ERRORS"

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "[DRY RUN] To actually ingest, run without --dry-run"
    echo "Ingested data goes to Qdrant collection: process_knowledge"
    echo "Query via: memory_recall with project=\"process_knowledge\""
fi
