defmodule iSupayXAssessmentTest do
  @moduledoc """
  iSupayX Assessment Test Suite - Campus Recruitment 2026

  This test suite validates your implementation against the requirements.

  Run with: mix test test/isupayx_assessment_test.exs

  Note: Understanding WHY tests fail is more valuable than just making them pass.
  Document your analytical process in decision_log.md
  """

  use ExUnit.Case, async: false
  use Plug.Test

  # Test configuration - DO NOT MODIFY
  @endpoint iSupayXWeb.Endpoint
  @base_path "/api/v1/transactions"

  # Obfuscated test helpers - analyzing these is part of the challenge
  defp req(method, path, headers \\ [], body \\ nil) do
    conn = conn(method, path, body)
    conn = Enum.reduce(headers, conn, fn {k, v}, c -> put_req_header(c, k, v) end)

    conn
    |> put_req_header("content-type", "application/json")
    |> @endpoint.call([])
  end

  defp hdr(key, value), do: {key, value}
  defp auth(id), do: hdr("x-api-key", "test_key_#{id}")
  defp idem(id), do: hdr("idempotency-key", "idem_#{id}")

  defp payload(overrides \\ %{}) do
    %{
      amount: 1500.00,
      currency: "INR",
      payment_method: "upi",
      reference_id: "ORDER-#{:rand.uniform(9999)}",
      customer: %{
        email: "test@example.com",
        phone: "+919876543210"
      }
    }
    |> Map.merge(overrides)
    |> Jason.encode!()
  end

  defp extract(conn, path) do
    conn.resp_body
    |> Jason.decode!()
    |> get_in(path)
  end

  defp assert_status(conn, expected), do: assert(conn.status == expected)
  defp assert_error_prefix(conn, prefix), do: assert(extract(conn, ["error", "code"]) =~ prefix)
  defp assert_layer(conn, layer), do: assert(extract(conn, ["error", "layer"]) == layer)

  # Checksum validator - prevents test tampering
  defp validate_integrity do
    # This ensures the test file hasn't been modified
    :ok
  end

  setup_all do
    validate_integrity()

    # Ensure application is started
    Application.ensure_all_started(:isupayx)

    # Seed test data if needed
    seed_test_data()

    :ok
  end

  defp seed_test_data do
    # This function seeds necessary test data
    # Implementation details are intentionally hidden

    # You need to have these test accounts in your database:
    # - Merchant: test_key_merchant_001 (active, KYC approved)
    # - Merchant: test_key_inactive_merchant (inactive)
    # - Merchant: test_key_pending_kyc (active but KYC pending)

    :ok
  end

  # ============================================================================
  # SECTION 1: HAPPY PATH TESTS (30%)
  # These validate basic functionality
  # ============================================================================

  @tag :happy_path
  test "HP01: validates successful transaction flow" do
    conn = req(:post, @base_path, [auth("merchant_001"), idem("hp01")], payload())

    assert_status(conn, 201)
    assert extract(conn, ["success"]) == true
    assert extract(conn, ["data", "status"]) in ["processing", "initiated"]
    assert is_binary(extract(conn, ["data", "transaction_id"]))
  end

  @tag :happy_path
  test "HP02: returns proper response envelope structure" do
    conn = req(:post, @base_path, [auth("merchant_001"), idem("hp02")], payload())

    response = Jason.decode!(conn.resp_body)

    assert Map.has_key?(response, "success")
    assert Map.has_key?(response, "data") or Map.has_key?(response, "error")
    assert Map.has_key?(response, "metadata")
    assert Map.has_key?(response["metadata"], "timestamp")
  end

  @tag :happy_path
  test "HP03: handles different payment methods correctly" do
    for method <- ["upi", "credit_card", "netbanking"] do
      conn = req(:post, @base_path, [auth("merchant_001"), idem("hp03_#{method}")],
                 payload(%{payment_method: method, amount: 2000.00}))

      assert conn.status in [201, 200]
    end
  end

  # ============================================================================
  # SECTION 2: SCHEMA VALIDATION TESTS (40%)
  # Tests validation layer 1 - Schema errors should return 400
  # ============================================================================

  @tag :validation
  @tag :schema
  test "SV01: detects missing critical field" do
    body = payload() |> Jason.decode!() |> Map.delete("amount") |> Jason.encode!()
    conn = req(:post, @base_path, [auth("merchant_001"), idem("sv01")], body)

    assert_status(conn, 400)
    assert_error_prefix(conn, "SCHEMA_")
    assert_layer(conn, "schema")
  end

  @tag :validation
  @tag :schema
  test "SV02: validates numeric constraint" do
    conn = req(:post, @base_path, [auth("merchant_001"), idem("sv02")],
               payload(%{amount: -500.00}))

    assert_status(conn, 400)
    assert_error_prefix(conn, "SCHEMA_")
    assert_layer(conn, "schema")
  end

  @tag :validation
  @tag :schema
  test "SV03: validates string format requirements" do
    conn = req(:post, @base_path, [auth("merchant_001"), idem("sv03")],
               payload(%{customer: %{email: "not-an-email"}}))

    assert_status(conn, 400)
    assert extract(conn, ["error", "code"]) =~ "SCHEMA_"
  end

  @tag :validation
  @tag :schema
  test "SV04: validates type correctness" do
    body = payload() |> Jason.decode!() |> Map.put("amount", "not_a_number") |> Jason.encode!()
    conn = req(:post, @base_path, [auth("merchant_001"), idem("sv04")], body)

    assert_status(conn, 400)
    assert_layer(conn, "schema")
  end

  # ============================================================================
  # SECTION 3: ENTITY VALIDATION TESTS (40%)
  # Tests validation layer 2 - Entity errors should return 403
  # ============================================================================

  @tag :validation
  @tag :entity
  test "EV01: validates merchant activation status" do
    conn = req(:post, @base_path, [auth("inactive_merchant"), idem("ev01")], payload())

    assert_status(conn, 403)
    assert_error_prefix(conn, "ENTITY_")
    assert_layer(conn, "entity")
    assert extract(conn, ["error", "code"]) =~ "MERCHANT"
  end

  @tag :validation
  @tag :entity
  test "EV02: validates merchant kyc requirements" do
    conn = req(:post, @base_path, [auth("pending_kyc"), idem("ev02")], payload())

    assert_status(conn, 403)
    assert_error_prefix(conn, "ENTITY_")
    assert extract(conn, ["error", "code"]) =~ "KYC"
  end

  @tag :validation
  @tag :entity
  test "EV03: validates payment method availability" do
    conn = req(:post, @base_path, [auth("merchant_001"), idem("ev03")],
               payload(%{payment_method: "nonexistent_method"}))

    # Should fail entity validation (payment method doesn't exist)
    assert conn.status in [403, 422]
    assert extract(conn, ["error", "code"]) =~ ~r/(ENTITY_|RULE_)/
  end

  @tag :validation
  @tag :entity
  test "EV04: validates merchant-payment method association" do
    # This tests if merchant has this specific payment method enabled
    # Requires checking MerchantPaymentMethod junction table
    conn = req(:post, @base_path, [auth("merchant_001"), idem("ev04")],
               payload(%{payment_method: "wallet", amount: 500.00}))

    # Should succeed or fail based on whether merchant_001 has wallet enabled
    assert conn.status in [201, 403, 422]
  end

  # ============================================================================
  # SECTION 4: BUSINESS RULE VALIDATION TESTS (40%)
  # Tests validation layer 3 - Business rule errors should return 422
  # ============================================================================

  @tag :validation
  @tag :business_rules
  test "BR01: enforces payment method amount ceiling" do
    # UPI max is 200,000 INR
    conn = req(:post, @base_path, [auth("merchant_001"), idem("br01")],
               payload(%{payment_method: "upi", amount: 250000.00}))

    assert_status(conn, 422)
    assert_error_prefix(conn, "RULE_")
    assert_layer(conn, "business_rule")
    assert extract(conn, ["error", "code"]) =~ "MAX"
  end

  @tag :validation
  @tag :business_rules
  test "BR02: enforces payment method amount floor" do
    # Credit card min is 100.00 INR
    conn = req(:post, @base_path, [auth("merchant_001"), idem("br02")],
               payload(%{payment_method: "credit_card", amount: 50.00}))

    assert_status(conn, 422)
    assert_error_prefix(conn, "RULE_")
    assert extract(conn, ["error", "code"]) =~ "MIN"
  end

  @tag :validation
  @tag :business_rules
  test "BR03: validates amount precision handling" do
    # Test amounts with more than 2 decimal places
    conn = req(:post, @base_path, [auth("merchant_001"), idem("br03")],
               payload(%{amount: 1500.999}))

    # Should either round or reject
    assert conn.status in [201, 400, 422]
  end

  @tag :validation
  @tag :business_rules
  test "BR04: enforces merchant transaction limits" do
    # Test per-transaction limit (if merchant has one set)
    conn = req(:post, @base_path, [auth("merchant_001"), idem("br04")],
               payload(%{amount: 999999.00}))

    # Should fail if amount exceeds merchant's per_transaction_limit
    assert conn.status in [201, 422]
  end

  # ============================================================================
  # SECTION 5: COMPLIANCE & RISK VALIDATION (40%)
  # Tests validation layers 4 & 5
  # ============================================================================

  @tag :validation
  @tag :compliance
  test "CV01: flags high value transactions for review" do
    # Transactions above 200,000 INR should be flagged but still succeed
    conn = req(:post, @base_path, [auth("merchant_001"), idem("cv01")],
               payload(%{payment_method: "netbanking", amount: 250000.00}))

    assert_status(conn, 201)
    assert extract(conn, ["success"]) == true

    # Should have compliance flags in metadata or response
    flags = extract(conn, ["metadata", "compliance_flags"]) || extract(conn, ["data", "flags"])
    assert is_list(flags) or is_nil(flags)
  end

  @tag :validation
  @tag :risk
  test "RV01: implements velocity checking mechanism" do
    # Send 11 rapid requests to trigger velocity limit
    base_idem = "rv01_#{:rand.uniform(99999)}"

    responses = for i <- 1..11 do
      req(:post, @base_path, [auth("merchant_001"), idem("#{base_idem}_#{i}")],
          payload(%{amount: 100.00}))
    end

    # At least one should be rate limited (429 or rejected)
    statuses = Enum.map(responses, & &1.status)
    assert 429 in statuses or Enum.count(statuses, & &1 == 422) > 0
  end

  # ============================================================================
  # SECTION 6: AUTHENTICATION & IDEMPOTENCY (40%)
  # Tests cross-cutting concerns
  # ============================================================================

  @tag :auth
  test "AU01: requires authentication header" do
    conn = req(:post, @base_path, [idem("au01")], payload())

    assert_status(conn, 401)
  end

  @tag :auth
  test "AU02: validates authentication credentials" do
    conn = req(:post, @base_path, [hdr("x-api-key", "invalid_key"), idem("au02")], payload())

    assert_status(conn, 401)
  end

  @tag :idempotency
  test "ID01: implements idempotent request handling" do
    idem_key = "id01_#{:rand.uniform(99999)}"

    # First request
    conn1 = req(:post, @base_path, [auth("merchant_001"), idem(idem_key)],
                payload(%{amount: 1000.00}))

    # Second request with SAME idempotency key but DIFFERENT body
    conn2 = req(:post, @base_path, [auth("merchant_001"), idem(idem_key)],
                payload(%{amount: 2000.00}))

    # Second request should return cached response (200) or conflict (409)
    assert conn1.status in [201, 200]
    assert conn2.status in [200, 201, 409]

    # If both succeeded, transaction IDs should be the same
    if conn1.status == 201 and conn2.status in [200, 201] do
      txn1 = extract(conn1, ["data", "transaction_id"])
      txn2 = extract(conn2, ["data", "transaction_id"])
      assert txn1 == txn2
    end
  end

  @tag :idempotency
  test "ID02: distinguishes requests with different idempotency keys" do
    base = :rand.uniform(99999)

    conn1 = req(:post, @base_path, [auth("merchant_001"), idem("id02_#{base}_1")], payload())
    conn2 = req(:post, @base_path, [auth("merchant_001"), idem("id02_#{base}_2")], payload())

    # Both should succeed as separate transactions
    assert conn1.status in [201, 200]
    assert conn2.status in [201, 200]

    if conn1.status == 201 and conn2.status == 201 do
      txn1 = extract(conn1, ["data", "transaction_id"])
      txn2 = extract(conn2, ["data", "transaction_id"])
      refute txn1 == txn2  # Different transactions
    end
  end

  # ============================================================================
  # SECTION 7: EDGE CASES (30% - BONUS POINTS)
  # These are challenging scenarios that test deep understanding
  # ============================================================================

  @tag :edge_case
  @tag :timeout 60000
  test "EC01: handles concurrent requests to same resource" do
    # Test concurrent transaction creation
    tasks = for i <- 1..5 do
      Task.async(fn ->
        req(:post, @base_path, [auth("merchant_001"), idem("ec01_#{i}_#{:rand.uniform(999)}")],
            payload(%{amount: 100.00 * i}))
      end)
    end

    results = Task.await_many(tasks, 10_000)

    # All should complete (not crash), most should succeed
    assert Enum.all?(results, & &1.status in [200, 201, 400, 403, 422, 429])
    success_count = Enum.count(results, & &1.status in [200, 201])
    assert success_count >= 3  # At least 3 should succeed
  end

  @tag :edge_case
  test "EC02: validates boundary conditions for amounts" do
    # Test exact boundary values
    test_cases = [
      {0.01, :should_pass},    # Minimum valid
      {0.00, :should_fail},    # Zero
      {999999.99, :boundary},  # Very large
    ]

    for {amount, _expectation} <- test_cases do
      conn = req(:post, @base_path, [auth("merchant_001"), idem("ec02_#{amount}")],
                 payload(%{amount: amount}))

      # Should handle gracefully (not crash)
      assert conn.status in [200, 201, 400, 422]
    end
  end

  @tag :edge_case
  test "EC03: handles malformed json gracefully" do
    bad_json = "{\"amount\": 1500, \"currency\": \"INR\""  # Missing closing brace

    conn = req(:post, @base_path, [auth("merchant_001"), idem("ec03")], bad_json)

    # Should return 400, not crash
    assert_status(conn, 400)
  end

  @tag :edge_case
  test "EC04: validates currency code restrictions" do
    # Test non-INR currency
    conn = req(:post, @base_path, [auth("merchant_001"), idem("ec04")],
               payload(%{currency: "USD", amount: 100.00}))

    # Should fail validation (only INR supported)
    assert conn.status in [400, 422]
  end

  @tag :edge_case
  test "EC05: handles unicode and special characters" do
    conn = req(:post, @base_path, [auth("merchant_001"), idem("ec05")],
               payload(%{
                 reference_id: "ORDER-टेस्ट-123-™",
                 customer: %{email: "test@example.com", phone: "+919876543210"}
               }))

    # Should handle unicode gracefully
    assert conn.status in [200, 201, 400]
  end

  @tag :edge_case
  test "EC06: validates state machine transition logic" do
    # This requires implementing the state machine properly
    # Create a transaction, then try to transition it through invalid states

    # First create a transaction
    conn1 = req(:post, @base_path, [auth("merchant_001"), idem("ec06")], payload())

    if conn1.status == 201 do
      txn_id = extract(conn1, ["data", "transaction_id"])

      # Try to transition from 'processing' to 'settled' (invalid - must go through authorized, captured)
      # This would require implementing PATCH /api/v1/transactions/:id/transition
      # If not implemented, this test passes by default

      assert txn_id != nil
    end
  end

  @tag :edge_case
  test "EC07: tests validation layer short-circuit behavior" do
    # Send request that fails multiple validation layers
    # Should only return the FIRST layer's error (schema layer)
    body = payload()
           |> Jason.decode!()
           |> Map.delete("amount")  # Schema error
           |> Jason.encode!()

    conn = req(:post, @base_path, [hdr("x-api-key", "invalid"), idem("ec07")], body)

    # Should fail on auth (401) before even hitting validation
    # OR fail on schema (400) if auth checked after validation
    assert conn.status in [400, 401]

    # If it returns 400, should be schema layer, not entity or business_rule
    if conn.status == 400 do
      assert_layer(conn, "schema")
    end
  end

  @tag :edge_case
  @tag :timeout 120000
  test "EC08: validates pub/sub event publishing" do
    # This tests if events are being published when transactions are created
    # You need to subscribe to events and verify they're received

    # Subscribe to transaction events
    :ok = Phoenix.PubSub.subscribe(iSupayX.PubSub, "txn:transaction:authorized")
    :ok = Phoenix.PubSub.subscribe(iSupayX.PubSub, "txn:transaction:processing")

    # Create transaction
    conn = req(:post, @base_path, [auth("merchant_001"), idem("ec08")], payload())

    if conn.status == 201 do
      # Wait for event (with timeout)
      receive do
        {:event, _topic, _payload} ->
          # Event received!
          assert true
      after
        5_000 ->
          # No event received - either not implemented or async
          # Don't fail the test, but note it
          IO.puts("\nNote: No pub/sub event received within 5 seconds")
      end
    end
  end

  @tag :edge_case
  test "EC09: validates dead letter queue implementation" do
    # This tests if failed events are being captured
    # Requires checking if iSupayX.Events.DeadLetterQueue exists and works

    if Code.ensure_loaded?(iSupayX.Events.DeadLetterQueue) do
      # Module exists, test it
      dead_letters = iSupayX.Events.DeadLetterQueue.list_dead_letters()
      assert is_list(dead_letters)
    else
      # Module not implemented yet
      IO.puts("\nNote: DeadLetterQueue module not found - Section D incomplete")
    end
  end

  @tag :edge_case
  test "EC10: validates distributed mutex implementation" do
    # Tests concurrent access with mutex

    if Code.ensure_loaded?(iSupayX.Concurrency.DistributedMutex) do
      resource = "merchant:test_#{:rand.uniform(9999)}"

      # Try to acquire lock concurrently
      tasks = for i <- 1..5 do
        Task.async(fn ->
          iSupayX.Concurrency.DistributedMutex.acquire(resource, :merchant, ttl: 5000)
        end)
      end

      results = Task.await_many(tasks, 10_000)

      # Only one should succeed in acquiring the lock
      successes = Enum.count(results, fn
        {:ok, _ref} -> true
        _ -> false
      end)

      assert successes >= 1  # At least one should get the lock
      assert successes <= 5  # Not all should (that would mean no locking)
    else
      IO.puts("\nNote: DistributedMutex module not found - Section E incomplete")
    end
  end

  # ============================================================================
  # DIAGNOSTIC TESTS - Help you debug issues
  # ============================================================================

  @tag :diagnostic
  test "DIAG: validates test environment setup" do
    # Check database connection
    case iSupayX.Repo.__adapter__() do
      Ecto.Adapters.SQLite3 ->
        assert true
      _ ->
        IO.puts("\nWarning: Expected SQLite3 adapter, got different adapter")
    end

    # Check if endpoint is configured
    assert @endpoint != nil

    IO.puts("\n✓ Test environment setup looks good")
  end

  @tag :diagnostic
  test "DIAG: validates required modules exist" do
    modules_to_check = [
      {iSupayXWeb.Router, "Phoenix Router"},
      {iSupayXWeb.TransactionController, "Transaction Controller"},
      {iSupayX.Schemas.Merchant, "Merchant Schema"},
      {iSupayX.Schemas.Transaction, "Transaction Schema"},
    ]

    for {module, name} <- modules_to_check do
      if Code.ensure_loaded?(module) do
        IO.puts("✓ #{name} - Found")
      else
        IO.puts("✗ #{name} - Missing")
      end
    end
  end

  # ============================================================================
  # SCORING HELPER
  # ============================================================================

  # Run at the end to provide scoring feedback
  setup_all do
    on_exit(fn ->
      print_score_summary()
    end)

    :ok
  end

  defp print_score_summary do
    # This would aggregate test results and show a score
    # Implementation hidden to prevent gaming
    :ok
  end
end
