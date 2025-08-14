#!/usr/bin/env bash
set -euo pipefail

# Paths
JSON_FILE="userdoc/users.json"
OUT_MD_TOP="USERS.md"
OUT_MD_DETAIL="userdoc/USER_ROSTER.md"
OUT_CSV="userdoc/users.csv"

# Check deps
command -v jq >/dev/null || { echo "jq is required"; exit 1; }

# Make sure input exists
[ -f "$JSON_FILE" ] || { echo "Missing $JSON_FILE"; exit 1; }

# Common JQ snippet to normalize groups to a string
JQ_GROUPS='(if (.groups | type) == "array" then (.groups | join(",")) else (.groups // "") end)'

# Generate top-level Markdown table
{
  echo "# Users"
  echo
  echo "| Username | Full Name | Role | Groups | Shell | GitHub | Notes |"
  echo "|---------:|-----------|------|--------|-------|--------|-------|"
  jq -r ".users[] | [ .username, .fullname, .role, ${JQ_GROUPS}, .shell, .github, .notes ]
         | @tsv" "$JSON_FILE" \
  | awk -F'\t' '{printf("| %s | %s | %s | %s | %s | %s | %s |\n",$1,$2,$3,$4,$5,$6,$7)}'
} > "$OUT_MD_TOP"

# Generate detailed roster Markdown
{
  echo "# User Roster"
  echo
  jq -r ".users[]
          | \"## \" + .username + \" (\" + .fullname + \")\"
            + \"\n- Role: \" + (.role // \"\")
            + \"\n- Groups: \" + (${JQ_GROUPS} // \"\")
            + \"\n- Shell: \" + (.shell // \"\")
            + \"\n- GitHub: \" + (.github // \"\")
            + \"\n- Notes: \" + (.notes // \"\") + \"\n\"" "$JSON_FILE"
} > "$OUT_MD_DETAIL"

# Generate CSV (header + rows)
{
  echo "username,fullname,role,groups,shell,github,notes"
  jq -r ".users[] | [ .username, .fullname, .role, ${JQ_GROUPS}, .shell, .github, .notes ] | @csv" "$JSON_FILE"
} > "$OUT_CSV"

echo "Generated:"
echo " - $OUT_MD_TOP"
echo " - $OUT_MD_DETAIL"
echo " - $OUT_CSV"
