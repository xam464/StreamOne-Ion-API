#!/bin/bash
set -euo pipefail

if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo "Error: .env file not found."
  exit 1
fi

for var in TD_SYNNEX_ACCESS_TOKEN TD_SYNNEX_REFRESH_TOKEN TD_SYNNEX_ACCOUNT_ID; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var must be set in .env."
    exit 1
  fi
done

BASE="https://ion.tdsynnex.com/api/v3/accounts/${TD_SYNNEX_ACCOUNT_ID}"

refresh_token() {
  local result
  result=$(curl -s -X POST "https://ion.tdsynnex.com/oauth/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=refresh_token&refresh_token=${TD_SYNNEX_REFRESH_TOKEN}")

  local new_access new_refresh
  new_access=$(printf "%s" "$result" | jq -r '.access_token // empty')
  new_refresh=$(printf "%s" "$result" | jq -r '.refresh_token // empty')

  if [ -z "$new_access" ]; then
    echo "Error: Failed to refresh access token." >&2
    exit 1
  fi

  TD_SYNNEX_ACCESS_TOKEN="$new_access"
  TD_SYNNEX_REFRESH_TOKEN="$new_refresh"

  # Persist new tokens to .env
  sed -i '' "s|TD_SYNNEX_ACCESS_TOKEN=.*|TD_SYNNEX_ACCESS_TOKEN=\"${new_access}\"|" .env
  sed -i '' "s|TD_SYNNEX_REFRESH_TOKEN=.*|TD_SYNNEX_REFRESH_TOKEN=\"${new_refresh}\"|" .env
}

api_get() {
  local url="$1"
  local result http_code body

  result=$(curl -s -w "\n%{http_code}" \
    -H "Authorization: Bearer ${TD_SYNNEX_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    "$url")

  http_code=$(printf "%s" "$result" | tail -n1)
  body=$(printf "%s" "$result" | sed '$d')

  if [ "$http_code" = "401" ]; then
    refresh_token
    result=$(curl -s -w "\n%{http_code}" \
      -H "Authorization: Bearer ${TD_SYNNEX_ACCESS_TOKEN}" \
      -H "Content-Type: application/json" \
      "$url")
    http_code=$(printf "%s" "$result" | tail -n1)
    body=$(printf "%s" "$result" | sed '$d')
  fi

  if [ "$http_code" != "200" ]; then
    echo "Error: HTTP $http_code from $url" >&2
    echo "$body" >&2
    exit 1
  fi

  printf "%s" "$body"
}

CSV_FILE=""
if [ "${1:-}" = "--csv" ]; then
  CSV_FILE="${2:-subscriptions_$(date +%Y%m%d_%H%M%S).csv}"
fi

print_row() {
  local customer="$1" subscription="$2" status="$3" qty="$4" price="$5" cost="$6" margin="$7" currency="$8" renewal="$9"
  printf "%-30s | %-40s | %-12s | %-5s | %-10s | %-10s | %-10s | %-10s | %s\n" \
    "${customer:0:30}" "${subscription:0:40}" "$status" "$qty" "$price" "$cost" "$margin" "$currency" "$renewal"
  if [ -n "$CSV_FILE" ]; then
    printf '"%s","%s","%s","%s","%s","%s","%s","%s","%s"\n' \
      "$customer" "$subscription" "$status" "$qty" "$price" "$cost" "$margin" "$currency" "$renewal" >> "$CSV_FILE"
  fi
}

if [ -n "$CSV_FILE" ]; then
  printf '"Customer","Subscription","Status","Qty","Price","Cost","Margin","Currency","Renewal Date"\n' > "$CSV_FILE"
fi

printf "%-30s | %-40s | %-12s | %-5s | %-10s | %-10s | %-10s | %-10s | %s\n" \
  "Customer" "Subscription" "Status" "Qty" "Price" "Cost" "Margin" "Currency" "Renewal Date"
printf "%s\n" "$(printf '%0.s-' {1..135})"

page_token=""
while true; do
  url="${BASE}/subscriptions"
  [ -n "$page_token" ] && url="${url}?pageToken=${page_token}"

  response=$(api_get "$url")

  while IFS=$'\t' read -r customer subscription status qty price cost margin currency renewal; do
    print_row "$customer" "$subscription" "$status" "$qty" "$price" "$cost" "$margin" "$currency" "$renewal"
  done < <(printf "%s" "$response" | jq -r '
    .items[]? |
    [
      (.customerName // "N/A"),
      (.subscriptionName // "N/A"),
      (.subscriptionStatus // "N/A"),
      (.subscriptionTotalLicenses // "N/A"),
      (.price // 0 | tostring),
      (.cost // 0 | tostring),
      (.margin // 0 | tostring),
      (.currency // "N/A"),
      (.renewalDate // "N/A" | if . != "N/A" then (.[0:10] | split("-") | "\(.[2])-\(.[1])-\(.[0])") else . end)
    ] | @tsv
  ')

  next=$(printf "%s" "$response" | jq -r '.nextPageToken // empty')
  [ -z "$next" ] && break
  page_token="$next"
done

if [ -n "$CSV_FILE" ]; then
  echo ""
  echo "Saved to: $CSV_FILE"
fi
