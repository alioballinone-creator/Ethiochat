# Regression Test Plan

## Unit Tests (≥85% coverage target)
- [x] phone_utils_test.dart - phone normalization/masking
- [x] failure_test.dart - error handling
- [x] outbox_worker_test.dart - backoff/state machine
- [ ] seq gap detection tests
- [ ] red-packet split tests (10,000 runs)
- [ ] ledger balance invariant tests
- [ ] Ethiopian calendar conversion tests

## Widget Tests
- [ ] All screens in light/dark mode
- [ ] Font scaling 1.0x and 2.0x
- [ ] en and am locales

## Integration Tests
- [ ] signup → send message
- [ ] offline send → reconnect delivery
- [ ] group create
- [ ] media send
- [ ] P2P transfer
- [ ] red packet claim
- [ ] call setup

## Backend Tests
- [ ] pgTAP for RLS policies
- [ ] pgTAP for triggers (seq assignment)
- [ ] Deno tests for Edge Functions
- [ ] Webhook replay/idempotency

## Chaos Tests
- [ ] 2G latency simulation
- [ ] 30% packet loss
- [ ] Mid-upload disconnect
- [ ] Airplane mode toggle
- [ ] App kill during send
- [ ] Zero duplicates/lost messages

## Concurrency Tests
- [ ] 50 clients to one conversation
- [ ] 100 simultaneous red-packet claims
