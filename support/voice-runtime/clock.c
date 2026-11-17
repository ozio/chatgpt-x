#include <stdint.h>
#include <sys/time.h>
#include <mbedtls/platform_time.h>
mbedtls_ms_time_t mbedtls_ms_time(void) {
    struct timeval now;
    if (gettimeofday(&now, 0)) return 0;
    return (mbedtls_ms_time_t)now.tv_sec * 1000 + now.tv_usec / 1000;
}
