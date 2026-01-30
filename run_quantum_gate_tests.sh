#!/bin/bash

# Quantum Gate Verification Test Suite Runner
# Runs all 142 tests and reports results

set -e

TESTS_PASSED=0
TESTS_FAILED=0

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           QUANTUM GATE VERIFICATION TEST SUITE                 ║"
echo "║                   142 Comprehensive Tests                      ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Exact quantum states
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 1: Exact Quantum States (29 tests)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESULT=$(godot --headless --script tests/test_gate_exact_states.gd 2>&1 | grep "RESULTS:")
echo "$RESULT"
PASSED=$(echo "$RESULT" | grep -oP '\d+(?= passed)')
FAILED=$(echo "$RESULT" | grep -oP '\d+(?= failed)')
TESTS_PASSED=$((TESTS_PASSED + PASSED))
TESTS_FAILED=$((TESTS_FAILED + FAILED))
echo ""

# Test 2: Advanced quantum states
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 2: Advanced Quantum States (28 tests)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESULT=$(godot --headless --script tests/test_advanced_quantum_states.gd 2>&1 | grep "RESULTS:")
echo "$RESULT"
PASSED=$(echo "$RESULT" | grep -oP '\d+(?= passed)')
FAILED=$(echo "$RESULT" | grep -oP '\d+(?= failed)')
TESTS_PASSED=$((TESTS_PASSED + PASSED))
TESTS_FAILED=$((TESTS_FAILED + FAILED))
echo ""

# Test 3: Gate application integration
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 3: Gate Application Integration (22 tests)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESULT=$(godot --headless --script tests/test_gate_application_integration.gd 2>&1 | grep "RESULTS:")
echo "$RESULT"
PASSED=$(echo "$RESULT" | grep -oP '\d+(?= passed)')
FAILED=$(echo "$RESULT" | grep -oP '\d+(?= failed)')
TESTS_PASSED=$((TESTS_PASSED + PASSED))
TESTS_FAILED=$((TESTS_FAILED + FAILED))
echo ""

# Test 4: 2-qubit gate embedding
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Test 4: 2-Qubit Gate Embedding (63 tests)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RESULT=$(godot --headless --script tests/test_2q_gate_embed.gd 2>&1 | grep "RESULTS:")
echo "$RESULT"
PASSED=$(echo "$RESULT" | grep -oP '\d+(?= passed)')
FAILED=$(echo "$RESULT" | grep -oP '\d+(?= failed)')
TESTS_PASSED=$((TESTS_PASSED + PASSED))
TESTS_FAILED=$((TESTS_FAILED + FAILED))
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                        FINAL RESULTS                           ║"
echo "╠════════════════════════════════════════════════════════════════╣"
printf "║  Total Tests:   %-44d║\n" $((TESTS_PASSED + TESTS_FAILED))
printf "║  ✅ Passed:     %-44d║\n" $TESTS_PASSED
printf "║  ❌ Failed:     %-44d║\n" $TESTS_FAILED
echo "╠════════════════════════════════════════════════════════════════╣"

if [ $TESTS_FAILED -eq 0 ]; then
    echo "║                    🎉 ALL TESTS PASSED! 🎉                     ║"
    echo "║         Quantum gates are density matrix verified!             ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo "║                     ⚠️  TESTS FAILED ⚠️                         ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    exit 1
fi
