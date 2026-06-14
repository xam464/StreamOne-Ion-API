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
    if [ "$customer" = "Customer" ]; then
      echo "$customer | $company | $provider | $cloudAccountId | Product | Price | Currency"
      continue
    fi

    if [ "$priceBookId" != "N/A" ] && [ -n "$priceBookId" ]; then
      # Get all price book items
      curl -s "https://ion.tdsynnex.com/api/v1/price-books/${priceBookId}" \
        -u "${TD_SYNNEX_API_KEY}:${TD_SYNNEX_API_SECRET}" | \
        jq -r '.data.items[] | "\(.productName // .name // .sku) | \(.price // .listPrice // "N/A") | \(.currency // "USD")"' | \
        while read -r product price currency; do
          echo "$customer | $company | $provider | $cloudAccountId | $product | $price | $currency"
        done
    else
      echo "$customer | $company | $provider | $cloudAccountId | N/A | N/A | USD"
    fi
  done
