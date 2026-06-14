#!/bin/bash
source .env

echo "Customer | Product/Plan | Provider | Price | Currency"
echo "---------------------------------------------------"

# Get all customers
customers_json=$(curl -s "https://ion.tdsynnex.com/api/v1/customers" \
  -u "${TD_SYNNEX_API_KEY}:${TD_SYNNEX_API_SECRET}")

# Process each customer
echo "$customers_json" | jq -c '.[]' | while read customer; do
  customer_id=$(echo "$customer" | jq -r '.id')
  customer_name=$(echo "$customer" | jq -r '.name // .companyName // .customerName // .id')

  # Get cloud accounts (products) for this customer
  cloud_accounts=$(curl -s "https://ion.tdsynnex.com/api/v1/customers/${customer_id}/cloud-accounts" \
    -u "${TD_SYNNEX_API_KEY}:${TD_SYNNEX_API_SECRET}")

  # Check if cloud-accounts returned data
  if [ "$(echo "$cloud_accounts" | jq 'type')" = "\"null\"" ] || [ "$(echo "$cloud_accounts" | jq 'length')" = "0" ]; then
    echo "$customer_name | No products | - | - | -"
    continue
  fi

  # Process each cloud account (product)
  echo "$cloud_accounts" | jq -c '.[] // empty' | while read account; do
    product_name=$(echo "$account" | jq -r '.name // .productName // .planName // .sku')
    provider=$(echo "$account" | jq -r '.provider // .cloudProvider // .vendor // "N/A"')
    price=$(echo "$account" | jq -r '.price // .listPrice // .unitPrice // .cost // "N/A"')
    currency=$(echo "$account" | jq -r '.currency // .priceCurrency // "USD"')

    echo "$customer_name | $product_name | $provider | $price $currency"
  done
done
