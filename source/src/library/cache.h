#ifndef PATCHMAN_YEAR_CACHE_H
#define PATCHMAN_YEAR_CACHE_H
#include <stdint.h>
#define YEAR_LIMIT 8192u
#define YEAR_MAGIC 0x52594d50u
struct YearRecord {uint32_t artist,album,year;};
struct YearHeader {uint32_t magic,version,count,checksum;};
static uint32_t year_checksum(const void *data,unsigned size){
 const unsigned char*p=data;uint32_t sum=2166136261u;
 for(unsigned i=0;i<size;i++)sum=(sum^p[i])*16777619u;
 return sum;
}
#endif
