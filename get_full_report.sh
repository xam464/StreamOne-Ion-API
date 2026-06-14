#!/bin/bash
source .env

echo "Customer | Company | Product/Provider | Cloud Account ID | Price Book ID"
echo "---------------------------------------------------------------------"

curl -s "https://ion.tdsynnex.com/api/v1/customers" \
  -u "${TD_SYNNEX_API_KEY}:${TD_SYNNEX_API_SECRET}" | \
  jq -r '.data.customer[] | . as $c | $c.cloudAccounts[] | 
    "\($c.name) | \($c.company) | \(.provider.name) | \(.cloudAccountId) | \($c.priceBooksLinks[0]?.priceBookId // "N/A")"'
