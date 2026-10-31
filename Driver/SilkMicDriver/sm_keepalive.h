// sm_keepalive.h — CoreAudio-free keepalive math for the SilkMic virtual mic.
//
// The SilkMic app writes the 'kpal' property every few seconds. If it stops (crash, quit,
// deleted, failed at login), the visible mic reports not-alive and not-default-eligible so
// macOS falls back to a real microphone instead of every app recording silence.
#ifndef SM_KEEPALIVE_H
#define SM_KEEPALIVE_H
#include <stdbool.h>
#include <stdint.h>

// lastHostTime == 0 means "never received". Times are mach_absolute_time ticks.
static inline bool sm_keepalive_is_alive(uint64_t lastHostTime, uint64_t nowHostTime,
                                         uint64_t timeoutTicks) {
    if (lastHostTime == 0) return false;
    if (nowHostTime <= lastHostTime) return true; // clock read raced the write
    return (nowHostTime - lastHostTime) <= timeoutTicks;
}

#endif
