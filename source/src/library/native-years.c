#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include "symbols.h"
#include "cache.h"
#ifndef CACHE_PATH
#define CACHE_PATH "/data/sony-peq/runtime/album-years.bin"
#endif
#ifndef LOG_PATH
#define LOG_PATH "/data/sony-peq/runtime/album-native-years.log"
#endif
/* Pinned Sony IdList ABI: ctor e0c0, GetCount e348, GetId e380,
 * GetInitialChar e3bc, MoveToFirst e450. Constructor sets cursor=ids.begin.
 * Search returns this completed object BEFORE the player builds its Qt model.
 * Reorder IDs and their paired initials together; never move/resize vectors. */
#include "list-layout.h"
#if UINTPTR_MAX == 0xffffffffu
_Static_assert(sizeof(struct NativeList)==40,"Sony list size");
_Static_assert(offsetof(struct NativeList,begin)==12,"Sony ID vector offset");
_Static_assert(offsetof(struct NativeList,initial)==24,"Sony initial vector offset");
_Static_assert(offsetof(struct NativeList,cursor)==36,"Sony cursor offset");
#elif !defined(PM_YEAR_TEST)
#error Native year shim is only for the pinned 32-bit ARM firmware
#endif
static pthread_mutex_t mutex=PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t log_mutex=PTHREAD_MUTEX_INITIALIZER;
struct FilterState{void*object;uint32_t artist,mask;unsigned epoch;int invalid;};
static struct FilterState filters[512];static unsigned serial,logs;
static __thread unsigned range_depth;
static struct YearRecord*records;static unsigned record_count;
static pthread_once_t cache_once=PTHREAD_ONCE_INIT;
static void log_event(const char*text,unsigned count,unsigned artist,unsigned first){
 char line[256];int size=snprintf(line,sizeof line,"native-years-1 [%ld] %s count=%u artist=0x%08x first=0x%08x\n",(long)getpid(),text,count,artist,first);
 if(size<1||size>=(int)sizeof line)return;
 pthread_mutex_lock(&log_mutex);
 if(logs++<128){int fd=open(LOG_PATH,O_WRONLY|O_CREAT|O_APPEND|O_CLOEXEC|O_NOFOLLOW,0666);if(fd>=0){struct stat st;if(!fstat(fd,&st)&&S_ISREG(st.st_mode)&&st.st_size+size<=32768){ssize_t ignored=write(fd,line,(size_t)size);(void)ignored;}close(fd);}}
 pthread_mutex_unlock(&log_mutex);
}
static struct FilterState*find(void*object,int create){
 if(!object)return NULL;struct FilterState*free_slot=NULL;
 for(unsigned i=0;i<512;i++){if(filters[i].object==object)return &filters[i];if(!filters[i].object&&!free_slot)free_slot=&filters[i];}
 if(create&&free_slot){free_slot->object=object;free_slot->epoch=++serial;return free_slot;}return NULL;
}
static void reset(void*object){pthread_mutex_lock(&mutex);struct FilterState*s=find(object,1);if(s){*s=(struct FilterState){.object=object,.epoch=++serial};}pthread_mutex_unlock(&mutex);}
static void erase(void*object){pthread_mutex_lock(&mutex);struct FilterState*s=find(object,0);if(s)memset(s,0,sizeof *s);pthread_mutex_unlock(&mutex);}
static void remember(void*object,int type,unsigned id){
 pthread_mutex_lock(&mutex);struct FilterState*s=find(object,0);
 if(s){
  s->epoch=++serial;
  if(type<0||type>31)s->invalid=1;else s->mask|=1u<<(unsigned)type;
  if(type==5){if((id&0xff000000u)!=0x84000000u||!(id&0xffffffu)||(s->artist&&s->artist!=id))s->invalid=1;s->artist=id;}
 }
 pthread_mutex_unlock(&mutex);
}
static struct FilterState snapshot(void*object){struct FilterState result={0};pthread_mutex_lock(&mutex);struct FilterState*s=find(object,0);if(s)result=*s;pthread_mutex_unlock(&mutex);return result;}
static void load_cache(void){
 int fd=open(CACHE_PATH,O_RDONLY|O_CLOEXEC|O_NOFOLLOW);if(fd<0){log_event("cache-missing",0,0,0);return;}
 struct stat st;struct YearHeader h;ssize_t n=read(fd,&h,sizeof h);
 if(fstat(fd,&st)||!S_ISREG(st.st_mode)||n!=(ssize_t)sizeof h||h.magic!=YEAR_MAGIC||h.version!=1||h.count>YEAR_LIMIT||st.st_size!=(off_t)(sizeof h+h.count*sizeof(struct YearRecord))){close(fd);log_event("cache-invalid",0,0,0);return;}
 struct YearRecord*data=calloc(h.count?h.count:1,sizeof *data);if(!data){close(fd);return;}
 size_t bytes=h.count*sizeof *data,at=0;while(at<bytes){ssize_t got=read(fd,(char*)data+at,bytes-at);if(got<=0)break;at+=(size_t)got;}close(fd);
 int good=at==bytes&&year_checksum(data,(unsigned)bytes)==h.checksum;
 for(unsigned i=0;good&&i<h.count;i++){
  struct YearRecord*r=&data[i];if((r->artist&0xff000000u)!=0x84000000u||!(r->artist&0xffffffu)||(r->album&0xff000000u)!=0x81000000u||!(r->album&0xffffffu)||(r->year&&(r->year<1000||r->year>2999)))good=0;
  if(i&&(data[i-1].artist>r->artist||(data[i-1].artist==r->artist&&data[i-1].album>=r->album)))good=0;
 }
 if(!good){free(data);log_event("cache-invalid",0,0,0);return;}
 records=data;record_count=h.count;log_event("cache-ready",h.count,0,0);
}
static unsigned lookup(unsigned artist,unsigned album){
 unsigned lo=0,hi=record_count;
 while(lo<hi){unsigned mid=lo+(hi-lo)/2;struct YearRecord*r=&records[mid];if(r->artist<artist||(r->artist==artist&&r->album<album))lo=mid+1;else hi=mid;}
 return lo<record_count&&records[lo].artist==artist&&records[lo].album==album?records[lo].year:0;
}
struct Ordered{uint32_t id,initial,year,index;};
static int compare(const void*a,const void*b){const struct Ordered*x=a,*y=b;return x->year!=y->year?(x->year>y->year?-1:1):(x->index>y->index)-(x->index<y->index);}
static int compare_id(const void*a,const void*b){uint32_t x=*(const uint32_t*)a,y=*(const uint32_t*)b;return (x>y)-(x<y);}
static int native_shape(struct NativeList*p){
 if(!p)return 0;
 void*get=dlsym(RTLD_NEXT,SYM_GET_COUNT);if(!get)return 0;
#ifdef PM_YEAR_TEST
 void*expected=dlsym(RTLD_NEXT,"patchman_mock_vtable");
 if(!expected||p->vtable!=expected)return 0;
#else
 Dl_info info;if(!dladdr(get,&info)||!info.dli_fbase)return 0;
 uintptr_t base=(uintptr_t)info.dli_fbase;
 if((((uintptr_t)get)&~(uintptr_t)1)-base!=0xe348u||p->vtable!=(void*)(base+0xd6610u))return 0;
#endif
 uintptr_t begin=(uintptr_t)p->begin,end=(uintptr_t)p->end,cap=(uintptr_t)p->capacity;
 uintptr_t initial=(uintptr_t)p->initial,initial_end=(uintptr_t)p->initial_end,initial_cap=(uintptr_t)p->initial_capacity;
 if(!begin||!initial||((begin|end|cap|initial|initial_end|initial_cap)&3u)||end<begin||cap<end||initial_end<initial||initial_cap<initial_end)return 0;
 unsigned count=(unsigned)((end-begin)/4);
 if(count<1||count>YEAR_LIMIT||cap-begin>YEAR_LIMIT*8u||initial_end-initial!=count*4u||initial_cap-initial>YEAR_LIMIT*8u||p->cursor!=p->begin)return 0;
 unsigned(*get_count)(void*)=(unsigned(*)(void*))get;
 return p->type==6&&get_count(p)==count;
}
static void order(int type,int rc,void**filter,void**out,struct FilterState before){
 if(range_depth||type!=6||rc||!filter||!*filter||!out||!*out||before.invalid||before.mask!=(1u<<5)||!before.artist)return;
 struct FilterState after=snapshot(*filter);if(after.epoch!=before.epoch||after.artist!=before.artist||after.invalid||after.mask!=before.mask)return;
 struct NativeList*p=*out;if(!native_shape(p)){log_event("shape-rejected",0,before.artist,0);return;}
 pthread_once(&cache_once,load_cache);if(!record_count)return;
 unsigned count=(unsigned)(p->end-p->begin);struct Ordered*sorted=malloc(count*sizeof *sorted);uint32_t*ids=malloc(count*sizeof *ids);
 if(!sorted||!ids){free(sorted);free(ids);return;}
 int good=1;
 for(unsigned i=0;i<count;i++){
  uint32_t id=p->begin[i];if((id&0xff000000u)!=0x81000000u||!(id&0xffffffu)){good=0;break;}
  ids[i]=id;sorted[i]=(struct Ordered){id,p->initial[i],lookup(before.artist,id),i};
 }
 if(good){qsort(ids,count,sizeof *ids,compare_id);for(unsigned i=1;i<count;i++)if(ids[i]==ids[i-1])good=0;}
 if(good){
  qsort(sorted,count,sizeof *sorted,compare);
  /* All validation and allocations are complete before the first write. */
  for(unsigned i=0;i<count;i++){p->begin[i]=sorted[i].id;p->initial[i]=sorted[i].initial;}
  log_event("ordered-before-model",count,before.artist,p->begin[0]);
 }
 free(sorted);free(ids);
}
void*ctor(void*,int,void*,int) __asm__(SYM_FILTER_CTOR);
void*ctor(void*self,int pid,void*service,int handle){
 /* ARM C++ constructors return this. CreateFilter at d2cc stores r0. */
 void*(*next)(void*,int,void*,int)=(void*(*)(void*,int,void*,int))dlsym(RTLD_NEXT,SYM_FILTER_CTOR);
 if(!next)return NULL;void*result=next(self,pid,service,handle);if(result==self)reset(self);return result;
}
int clear(void*) __asm__(SYM_FILTER_CLEAR);
int clear(void*self){int(*next)(void*)=(int(*)(void*))dlsym(RTLD_NEXT,SYM_FILTER_CLEAR);if(!next)return 16;int rc=next(self);if(!rc)reset(self);return rc;}
int set(void*,int,unsigned) __asm__(SYM_SET_FILTER);
int set(void*self,int type,unsigned id){int(*next)(void*,int,unsigned)=(int(*)(void*,int,unsigned))dlsym(RTLD_NEXT,SYM_SET_FILTER);if(!next)return 16;int rc=next(self,type,id);if(!rc)remember(self,type,id);return rc;}
int search(void*,int,void**,void**) __asm__(SYM_SEARCH_FILTER);
int search(void*self,int type,void**filter,void**out){
 int(*next)(void*,int,void**,void**)=(int(*)(void*,int,void**,void**))dlsym(RTLD_NEXT,SYM_SEARCH_FILTER);if(!next)return 16;
 struct FilterState before=snapshot(filter?*filter:NULL);int rc=next(self,type,filter,out);order(type,rc,filter,out,before);return rc;
}
int range(void*,int,void**,unsigned,unsigned,void**) __asm__(SYM_SEARCH_RANGE);
int range(void*self,int type,void**filter,unsigned start,unsigned count,void**out){
 int(*next)(void*,int,void**,unsigned,unsigned,void**)=(int(*)(void*,int,void**,unsigned,unsigned,void**))dlsym(RTLD_NEXT,SYM_SEARCH_RANGE);if(!next)return 16;
 range_depth++;int rc=next(self,type,filter,start,count,out);range_depth--;return rc;
}
/* Filter objects are short-lived; release bookkeeping without another Sony call. */
void*dtor(void*) __asm__("_ZN3pst8services10mediastore6FilterD1Ev");
void*dtor(void*self){void*(*next)(void*)=(void*(*)(void*))dlsym(RTLD_NEXT,"_ZN3pst8services10mediastore6FilterD1Ev");erase(self);return next?next(self):self;}
void*dtor_base(void*) __asm__("_ZN3pst8services10mediastore6FilterD2Ev");
void*dtor_base(void*self){void*(*next)(void*)=(void*(*)(void*))dlsym(RTLD_NEXT,"_ZN3pst8services10mediastore6FilterD2Ev");erase(self);return next?next(self):self;}
void*dtor_delete(void*) __asm__("_ZN3pst8services10mediastore6FilterD0Ev");
void*dtor_delete(void*self){void*(*next)(void*)=(void*(*)(void*))dlsym(RTLD_NEXT,"_ZN3pst8services10mediastore6FilterD0Ev");erase(self);return next?next(self):self;}
