#!/bin/bash

# Flutter Test Runner for MicroFlow Pro
# Usage: ./scripts/run_tests.sh [unit|widget|integration|all]

set -e

MODE=${1:-all}

echo "========================================"
echo "MicroFlow Pro - Test Suite"
echo "========================================"

case "$MODE" in
  unit)
    echo ">>> Running Unit Tests..."
    flutter test test/unit/ --reporter=expanded
    ;;
  widget)
    echo ">>> Running Widget Tests..."
    flutter test test/widget/ --reporter=expanded
    ;;
  integration)
    echo ">>> Running Integration Tests..."
    flutter test integration_test/ --reporter=expanded
    ;;
  all)
    echo ">>> Running ALL Tests..."
    echo ""
    echo "--- Unit Tests ---"
    flutter test test/unit/ --reporter=expanded || exit 1
    echo ""
    echo "--- Widget Tests ---"
    flutter test test/widget/ --reporter=expanded || exit 1
    echo ""
    echo "--- Static Analysis ---"
    flutter analyze || exit 1
    echo ""
    echo "========================================"
    echo "ALL TESTS PASSED!"
    echo "========================================"
    ;;
  *)
    echo "Usage: $0 [unit|widget|integration|all]"
    exit 1
    ;;
esac