#!/bin/bash
source .env

echo "Customer | Company | Provider | Cloud Account | Product | Price | Currency"
echo "--------------------------------------------------------------------------"

curl -s "https://ion.tdsynnex.com/api/v1/customers" \
  -u "${TD_SYNNEX_API_KEY}:${TD_SYNNEX_API_SECRET}" | \
  jq -r '.data.customer[] | . as $c | $c.cloudAccounts[] | 
    {
      customer: $c.name,
      company: $c.company,
      provider: .provider.name,
      cloudAccountId: .cloudAccountId,
      priceBookId: $c.priceBooksLinks[0]?.priceBookId // "N/A"
    } | "\(.customer) | \(.company) | \(.provider) | \(.cloudAccountId) | \(.priceBookId)"' | \
  while IFS='|' read -r customer company provider cloudAccountId priceBookId; do
    # Skip header
    if [ "$customer" = "Customer" ]; then
      echo "$customer | $company | $provider | $cloudAccountId | $priceBookId"
      continue
    fi

    if [ "$priceBookId" != "N/A" ] && [ -n "$priceBookId" ]; then
      # Get price book details
      prices=$(curl -s "https://ion.tdsynnex.com/api/v1/price-books/${priceBookId}" \
        -u "${TD_SYNNEX_API_KEY}:${TD_SYNNEX_API_SECRET}" | \
        jq -r '.data.items[]? | "\(.productName // .name // .sku) | \(.price // .listPrice // "N/A") | \(.currency // "USD")" | head -1')
    else
      prices="N/A | N/A | USD"
    fi

    echo "$customer | $company | $provider | $cloudAccountId | $prices"
  done
