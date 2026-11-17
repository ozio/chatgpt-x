/* Pinned Mbed TLS 3.6.7; new ABI, rebuild EVERY Mbed caller and archive. */
#undef MBEDTLS_HAVE_ASM
#undef MBEDTLS_AESNI_C
#define MBEDTLS_PLATFORM_MS_TIME_ALT
#define MBEDTLS_THREADING_C
#define MBEDTLS_THREADING_PTHREAD
