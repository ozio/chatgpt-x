#include "OR6WebPortNamespace.h"
#include <string.h>
#include <limits.h>
#include <stdint.h>
#if defined(__arm__)
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach/vm_prot.h>
#endif
static char Loader[PATH_MAX],Engine[PATH_MAX];static size_t EngineLength;static unsigned Patches;static int Installed;
int OR6WebPortNamespaceCompare(const char *left,const char *right,size_t count){
    // Keep every ordinary strncmp call intact. The author's four loader checks
    // use exactly this nine-byte namespace literal after path relocation.
    if(count==9&&EngineLength&&memcmp(right,"./WebKit/",9)==0&&strncmp(left,Engine,EngineLength)==0)return 0;
    return strncmp(left,right,count);
}
unsigned OR6WebPortNamespacePatchCount(void){return Patches;}
#if defined(__arm__)
static void Loaded(const struct mach_header *header,intptr_t slide){
    const char *path=NULL;
    for(uint32_t i=0;i<_dyld_image_count();i++)if(_dyld_get_image_header(i)==header){path=_dyld_get_image_name(i);break;}
    if(!path||strcmp(path,Loader)||header->magic!=MH_MAGIC||header->ncmds>128)return;
    const struct symtab_command *symbols=NULL;const struct dysymtab_command *indirect=NULL;uintptr_t linkedit=0;
    const struct load_command *command=(const struct load_command *)(header+1);const char *end=(const char *)(header+1)+header->sizeofcmds;
    for(uint32_t i=0;i<header->ncmds;i++){
        if(command->cmdsize<8||(const char *)command+command->cmdsize>end)return;
        if(command->cmd==LC_SYMTAB)symbols=(const struct symtab_command *)command;
        else if(command->cmd==LC_DYSYMTAB)indirect=(const struct dysymtab_command *)command;
        else if(command->cmd==LC_SEGMENT){const struct segment_command *s=(const struct segment_command *)command;if(!strcmp(s->segname,SEG_LINKEDIT))linkedit=(uintptr_t)slide+s->vmaddr-s->fileoff;}
        command=(const struct load_command *)((const char *)command+command->cmdsize);
    }
    if(!symbols||!indirect||!linkedit)return;
    const struct nlist *table=(const struct nlist *)(linkedit+symbols->symoff);const char *strings=(const char *)(linkedit+symbols->stroff);const uint32_t *indices=(const uint32_t *)(linkedit+indirect->indirectsymoff);
    command=(const struct load_command *)(header+1);
    for(uint32_t i=0;i<header->ncmds;i++){
        if(command->cmd==LC_SEGMENT){
            const struct segment_command *segment=(const struct segment_command *)command;
            // These original SDK6.1 loader pointer tables are writable __DATA.
            // Refuse other layouts rather than changing global page permissions.
            if(segment->initprot&VM_PROT_WRITE){
                const struct section *sections=(const struct section *)(segment+1);
                for(uint32_t j=0;j<segment->nsects;j++){
                    const struct section *s=&sections[j];uint32_t type=s->flags&SECTION_TYPE;
                    if(type!=S_LAZY_SYMBOL_POINTERS&&type!=S_NON_LAZY_SYMBOL_POINTERS)continue;
                    uint32_t count=s->size/sizeof(uintptr_t);if(s->reserved1>indirect->nindirectsyms||count>indirect->nindirectsyms-s->reserved1)return;
                    uintptr_t *slots=(uintptr_t *)((uintptr_t)slide+s->addr);
                    for(uint32_t k=0;k<count;k++){
                        uint32_t index=indices[s->reserved1+k];if(index&(INDIRECT_SYMBOL_LOCAL|INDIRECT_SYMBOL_ABS))continue;
                        if(index>=symbols->nsyms||table[index].n_un.n_strx>=symbols->strsize)continue;
                        const char *name=strings+table[index].n_un.n_strx;
                        if(strcmp(name,"_strncmp"))continue;
                        uintptr_t replacement=(uintptr_t)&OR6WebPortNamespaceCompare;
                        if(slots[k]!=replacement){slots[k]=replacement;__sync_synchronize();Patches++;}
                    }
                }
            }
        }
        command=(const struct load_command *)((const char *)command+command->cmdsize);
    }
}
#endif
int OR6WebPortInstallNamespaceAdapter(const char *loaderPath,const char *engineRoot){
    if(Installed||!loaderPath||!engineRoot||loaderPath[0]!='/'||engineRoot[0]!='/')return 0;
    size_t a=strlen(loaderPath),b=strlen(engineRoot);if(!a||!b||a>=sizeof(Loader)||b+1>=sizeof(Engine))return 0;
    memcpy(Loader,loaderPath,a+1);memcpy(Engine,engineRoot,b);if(engineRoot[b-1]!='/')Engine[b++]='/';Engine[b]=0;EngineLength=b;Installed=1;
#if defined(__arm__)
    _dyld_register_func_for_add_image(Loaded);
#endif
    return 1;
}
