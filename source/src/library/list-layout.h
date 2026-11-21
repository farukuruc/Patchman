#ifndef PATCHMAN_NATIVE_LIST_LAYOUT_H
#define PATCHMAN_NATIVE_LIST_LAYOUT_H
#include <stdint.h>
struct NativeList {
 void*vtable;uint32_t owner;unsigned char type,pad[3];
 uint32_t*begin,*end,*capacity,*initial,*initial_end,*initial_capacity,*cursor;
};
#endif
