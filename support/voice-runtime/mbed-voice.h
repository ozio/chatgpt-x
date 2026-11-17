/* Separate ABI/config/archive from the accepted HTTP TLS build. */
#undef MBEDTLS_HAVE_ASM
#undef MBEDTLS_AESNI_C
#define MBEDTLS_SSL_DTLS_SRTP
#define MBEDTLS_THREADING_C
#define MBEDTLS_THREADING_PTHREAD
#define MBEDTLS_PLATFORM_MS_TIME_ALT
