# iSupayX Assessment - Test Data Seeder
# Seeds the SQLite database with test data for automated evaluation

alias iSupayX.Repo
alias iSupayX.Schemas.{Merchant, Transaction, PaymentMethod, MerchantPaymentMethod}

# Clear existing data
Repo.delete_all(MerchantPaymentMethod)
Repo.delete_all(Transaction)
Repo.delete_all(Merchant)
Repo.delete_all(PaymentMethod)

IO.puts("Seeding test data...")

# Create Payment Methods
payment_methods = [
  %{
    method_id: "upi",
    name: "UPI",
    min_amount: Decimal.new("1.00"),
    max_amount: Decimal.new("200000.00"),
    processing_fee_percent: Decimal.new("0.00"),
    is_active: true
  },
  %{
    method_id: "credit_card",
    name: "Credit Card",
    min_amount: Decimal.new("100.00"),
    max_amount: Decimal.new("500000.00"),
    processing_fee_percent: Decimal.new("2.50"),
    is_active: true
  },
  %{
    method_id: "debit_card",
    name: "Debit Card",
    min_amount: Decimal.new("100.00"),
    max_amount: Decimal.new("200000.00"),
    processing_fee_percent: Decimal.new("1.80"),
    is_active: true
  },
  %{
    method_id: "netbanking",
    name: "Net Banking",
    min_amount: Decimal.new("10.00"),
    max_amount: Decimal.new("1000000.00"),
    processing_fee_percent: Decimal.new("1.20"),
    is_active: true
  },
  %{
    method_id: "wallet",
    name: "Digital Wallet",
    min_amount: Decimal.new("10.00"),
    max_amount: Decimal.new("100000.00"),
    processing_fee_percent: Decimal.new("1.50"),
    is_active: true
  }
]

Enum.each(payment_methods, fn pm_attrs ->
  %PaymentMethod{}
  |> PaymentMethod.changeset(pm_attrs)
  |> Repo.insert!()
end)

IO.puts("✓ Created #{length(payment_methods)} payment methods")

# Create Test Merchants
merchants = [
  %{
    merchant_id: "test_merchant_001",
    api_key: "test_key_merchant_001",
    name: "Active Test Merchant",
    email: "merchant001@example.com",
    onboarding_status: "activated",
    kyc_status: "approved",
    daily_transaction_limit: Decimal.new("1000000.00"),
    per_transaction_limit: Decimal.new("500000.00"),
    is_active: true
  },
  %{
    merchant_id: "test_merchant_002",
    api_key: "test_key_merchant_002",
    name: "Active Merchant #2",
    email: "merchant002@example.com",
    onboarding_status: "activated",
    kyc_status: "verified",  # Testing legacy enum value
    daily_transaction_limit: Decimal.new("500000.00"),
    per_transaction_limit: Decimal.new("200000.00"),
    is_active: true
  },
  %{
    merchant_id: "inactive_merchant",
    api_key: "test_key_inactive_merchant",
    name: "Inactive Test Merchant",
    email: "inactive@example.com",
    onboarding_status: "review",
    kyc_status: "approved",
    daily_transaction_limit: Decimal.new("100000.00"),
    per_transaction_limit: Decimal.new("50000.00"),
    is_active: false
  },
  %{
    merchant_id: "pending_kyc_merchant",
    api_key: "test_key_pending_kyc",
    name: "Pending KYC Merchant",
    email: "pendingkyc@example.com",
    onboarding_status: "activated",
    kyc_status: "pending",
    daily_transaction_limit: Decimal.new("50000.00"),
    per_transaction_limit: Decimal.new("10000.00"),
    is_active: true
  },
  %{
    merchant_id: "not_started_kyc",
    api_key: "test_key_not_started",
    name: "Not Started KYC",
    email: "notstarted@example.com",
    onboarding_status: "activated",
    kyc_status: "not_started",  # New enum value
    daily_transaction_limit: Decimal.new("10000.00"),
    per_transaction_limit: Decimal.new("5000.00"),
    is_active: true
  }
]

inserted_merchants = Enum.map(merchants, fn merchant_attrs ->
  %Merchant{}
  |> Merchant.changeset(merchant_attrs)
  |> Repo.insert!()
end)

IO.puts("✓ Created #{length(merchants)} test merchants")

# Create Merchant-PaymentMethod Associations
# Active merchant supports UPI, Credit Card, and Net Banking
active_merchant = Enum.at(inserted_merchants, 0)
upi = Repo.get_by!(PaymentMethod, method_id: "upi")
credit_card = Repo.get_by!(PaymentMethod, method_id: "credit_card")
netbanking = Repo.get_by!(PaymentMethod, method_id: "netbanking")

associations = [
  %{
    merchant_id: active_merchant.id,
    payment_method_id: upi.id,
    custom_fee_percent: Decimal.new("0.00"),
    is_enabled: true,
    priority: 1
  },
  %{
    merchant_id: active_merchant.id,
    payment_method_id: credit_card.id,
    custom_fee_percent: Decimal.new("2.50"),
    is_enabled: true,
    priority: 2
  },
  %{
    merchant_id: active_merchant.id,
    payment_method_id: netbanking.id,
    custom_fee_percent: Decimal.new("1.20"),
    is_enabled: true,
    priority: 3
  }
]

Enum.each(associations, fn assoc_attrs ->
  %MerchantPaymentMethod{}
  |> MerchantPaymentMethod.changeset(assoc_attrs)
  |> Repo.insert!()
end)

IO.puts("✓ Created #{length(associations)} merchant-payment method associations")

# Create some test transactions for historical data
test_transactions = [
  %{
    transaction_id: "txn_test_001",
    merchant_id: active_merchant.id,
    payment_method_id: upi.id,
    amount: Decimal.new("1500.00"),
    currency: "INR",
    status: "settled",
    reference_id: "ORDER-SEED-001",
    customer_email: "customer1@example.com",
    customer_phone: "+919876543210"
  },
  %{
    transaction_id: "txn_test_002",
    merchant_id: active_merchant.id,
    payment_method_id: credit_card.id,
    amount: Decimal.new("5000.00"),
    currency: "INR",
    status: "processing",
    reference_id: "ORDER-SEED-002",
    customer_email: "customer2@example.com"
  }
]

Enum.each(test_transactions, fn txn_attrs ->
  %Transaction{}
  |> Transaction.changeset(txn_attrs)
  |> Repo.insert!()
end)

IO.puts("✓ Created #{length(test_transactions)} test transactions")

IO.puts("\n✅ Test data seeding completed successfully!")
IO.puts("\nTest Credentials:")
IO.puts("  Active Merchant API Key: test_key_merchant_001")
IO.puts("  Inactive Merchant API Key: test_key_inactive_merchant")
IO.puts("  Pending KYC Merchant API Key: test_key_pending_kyc")
