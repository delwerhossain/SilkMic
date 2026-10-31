// test_sm_keepalive.c — host test for the keepalive window used by the SilkMic driver.
#include <assert.h>
#include <stdio.h>
#include "../SilkMicDriver/sm_keepalive.h"

int main(void) {
    const uint64_t timeout = 10000;

    // Never received: not alive, whatever the time.
    assert(!sm_keepalive_is_alive(0, 0, timeout));
    assert(!sm_keepalive_is_alive(0, 123456, timeout));

    // Fresh write: alive.
    assert(sm_keepalive_is_alive(1000, 1000, timeout));
    assert(sm_keepalive_is_alive(1000, 1000 + timeout, timeout));

    // Stale by one tick: not alive.
    assert(!sm_keepalive_is_alive(1000, 1000 + timeout + 1, timeout));

    // Clock read raced the write (now earlier than last): treat as alive.
    assert(sm_keepalive_is_alive(5000, 4000, timeout));

    printf("sm_keepalive: all tests passed\n");
    return 0;
}
