#include <stddef.h>
// Adapts only the copied WK26 loader's namespace predicate. Never spoofs image
// paths or changes global libc behavior. Configure before dlopen of that loader.
int OR6WebPortInstallNamespaceAdapter(const char *loaderPath,const char *engineRoot);
unsigned OR6WebPortNamespacePatchCount(void);
int OR6WebPortNamespaceCompare(const char *left,const char *right,size_t count);
