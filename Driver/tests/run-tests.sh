#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
rm -f /tmp/nn_ring_test /tmp/nn_clock_test /tmp/sm_keepalive_test
clang -std=c11 -Wall -Wextra -O2 test_nn_ring.c  ../SilkMicDriver/nn_ring.c  -o /tmp/nn_ring_test
clang -std=c11 -Wall -Wextra -O2 test_nn_clock.c ../SilkMicDriver/nn_clock.c -o /tmp/nn_clock_test
clang -std=c11 -Wall -Wextra -O2 test_sm_keepalive.c -o /tmp/sm_keepalive_test
/tmp/nn_ring_test
/tmp/nn_clock_test
/tmp/sm_keepalive_test
