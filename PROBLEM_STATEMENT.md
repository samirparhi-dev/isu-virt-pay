# iSupayX Payment Gateway - Engineering Challenge

## 📋 Your Task

Build a **transaction processing API** for iSupayX, a payment gateway that handles UPI, credit cards, debit cards, and net banking transactions.

**Duration:** 4 hours
**Evaluation:** Code quality + System design + Problem-solving process

---

## ⚙️ Mandatory Requirements

### Technology Stack
- ✅ **VS Code** - You must install and use VS Code and their plugins
- ✅ **Elixir 1.14+** - Programming Language
- ✅ **Phoenix Framework** - API-only mode
- ✅ **SQLite** - Database (via ecto)
- ✅  **Ecto** - for DB Simulation
- ✅ **Git** - Version control with incremental commits

**⚠️ IMPORTANT:** Environment setup is part of this assessment. No installation support will be provided.

---

## What to Build

### API Endpoint: `POST /api/v1/transactions`

**Request:**
```json
{
  "amount": 1500.00,
  "currency": "INR",
  "payment_method": "upi",
  "reference_id": "ORDER-001",
  "customer": {
    "email": "customer@example.com",
    "phone": "+919876543210"
  }
}
```

**Required Headers:**
- `X-Api-Key` - Merchant authentication
- `Idempotency-Key` - Prevent duplicate processing

**Success Response (201):**
```json
{
  "success": true,
  "data": {
    "transaction_id": "txn_abc123",
    "status": "processing",
    "amount": 1500.00,
    "currency": "INR"
  },
  "metadata": {
    "request_id": "req_xyz",
    "timestamp": "2026-02-07T10:30:00Z"
  }
}
```

**Error Response (400/403/422):**
```json
{
  "success": false,
  "error": {
    "code": "SCHEMA_MISSING_FIELD",
    "message": "Required field 'amount' is missing",
    "layer": "schema",
    "details": [
      {"field": "amount", "rule": "required", "message": "is required"}
    ]
  },
  "metadata": {
    "request_id": "req_xyz",
    "timestamp": "2026-02-07T10:30:00Z"
  }
}
```

---

## Core Requirements

### 1. Five-Layer Validation Pipeline

**Your API must validate requests through these layers IN ORDER:**

| Layer | Error Prefix | HTTP Status | What to Check |
|-------|--------------|-------------|---------------|
| 1. Schema | `SCHEMA_` | 400 | Required fields, data types, formats |
| 2. Entity | `ENTITY_` | 403 | Merchant exists & active, KYC approved |
| 3. Business Rules | `RULE_` | 422 | Amount limits, per-transaction limits |
| 4. Compliance | `COMPLIANCE_` | 201* | Flag large transactions (>₹200,000) |
| 5. Risk | `RISK_` | 429 | Velocity check (>10 txns in 5 min) |

**\*Compliance:** Transaction succeeds but is flagged for review (Bonus point)

**Critical:** Stop at first failure. Don't run subsequent layers.


### Async Event System

**Publish events when transaction state changes:**
- Event format: `{event_id, event_type, transaction_id, merchant_id, amount, timestamp, data}`
- Topics: `txn:transaction:authorized`, `txn:transaction:failed`, etc.
- Use Phoenix.PubSub

**Subscriber Requirements:**
- Subscribe to transaction events
- Simulate webhook notifications (just log, don't send HTTP)
- Handle failures with Dead Letter Queue
- Retry with exponential backoff: 1s, 5s, 30s

**Back-pressure:**
- If mailbox > 100 messages, drop non-critical events
- Keep critical events (authorized, failed)

---

### Concurrency Control (20 points)

### Document Analysis (40 points)

**Analyze the iSupayX specification document and find:**

**A.1 Validation Layers (15 points)**
- List all 5 validation layers
- Explain their execution order and WHY
- Document error code prefixes

**A.2 Contradictions (15 points)**
- Find at least 3 intentional contradictions
- Cite specific sections
- Propose resolution strategies

**A.3 Hidden Dependencies (10 points)**
- Identify the many-to-many relationship described only in prose
- List additional fields beyond foreign keys
- Explain impact on validation

**Document all findings in `decision_log.md`**

---

### Decision Log (30 points)

Create `decision_log.md` with these sections:

```markdown
## Approach & Prioritization
[What you tackled first and why]

## AI Interaction Log
[At least 5 examples: what AI got wrong, how you fixed it]

## Validation Layer Analysis
[Your findings from Document Analysis]

## Contradictions Found
[List with citations and resolutions]

## Hidden Dependencies
[Your findings from Document Analysis]

## Architecture Decisions
[Why Phoenix? Module structure? Data structure choices?]

## What I Would Do Differently
[Honest reflection with more time]

## Known Limitations
[Bugs/edge cases you know about but didn't fix]
```

---

## Testing Your Code

**We provide a test suite:** `isupayx_assessment_test.exs`

```bash
# Copy to your project
cp isupayx_assessment_test.exs test/

# Run tests
mix test test/isupayx_assessment_test.exs

# Initially: Many failures (expected)
# Goal: Pass 70%+ of tests
```


## 🚫 Guardrails

- ❌ Languages other than Elixir for core implementation
- ❌ Heavy infrastructure (Redis, Postgres, RabbitMQ)
- ❌ Copying entire solutions without understanding
- ❌ Not documenting your decision log

## ✅ Allowed & Encouraged

- ✅ AI tools (any of your choice) - **BUT document what went wrong**
- ✅ Documentation (hexdocs.pm, Phoenix guides)
- ✅ Google, Stack Overflow
- ✅ Making reasonable assumptions (document them!)
- ✅ Incomplete features with good documentation

---

## 🏁 Getting Started

```bash

# Verify
elixir --version

# Install Phoenix
mix archive.install hex phx_new

# Create project
mix phx.new isupayx --no-html --no-assets --database sqlite3
cd isupayx
mix deps.get
mix ecto.create

# Start server
mix phx.server
```

---

## Good Luck! 🚀

