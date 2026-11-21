#include <stdint.h>
#include "symbols.h"
#include "list-layout.h"
char patchman_mock_vtable[16];
static uint32_t ids[3],initials[3];static struct NativeList list;static int mode;
void mock_mode(int value){mode=value;}
void*ctor(void*,int,void*,int) __asm__(SYM_FILTER_CTOR);
void*ctor(void*self,int pid,void*service,int handle){(void)pid;(void)service;(void)handle;return self;}
int clear(void*) __asm__(SYM_FILTER_CLEAR);
int clear(void*self){return self?0:9;}
int set(void*,int,unsigned) __asm__(SYM_SET_FILTER);
int set(void*self,int type,unsigned id){(void)id;return self&&type!=31?0:9;}
int full(void*,int,void**,void**) __asm__(SYM_SEARCH_FILTER);
int full(void*self,int type,void**filter,void**out){
 if(!self||!filter||!*filter||mode==9)return 9;
 ids[0]=0x81000001;ids[1]=0x81000002;ids[2]=mode==1?0x81000001:0x81000003;
 initials[0]='A';initials[1]='B';initials[2]='C';
 list=(struct NativeList){.vtable=mode==2?(void*)0xfeed:patchman_mock_vtable,.type=(unsigned char)type,.begin=ids,.end=ids+3,.capacity=ids+3,.initial=initials,.initial_end=initials+3,.initial_capacity=initials+3,.cursor=mode==3?ids+1:ids};
 *out=&list;return 0;
}
int range(void*,int,void**,unsigned,unsigned,void**) __asm__(SYM_SEARCH_RANGE);
int range(void*self,int type,void**filter,unsigned start,unsigned count,void**out){return start==5&&count==9?full(self,type,filter,out):9;}
unsigned count(void*) __asm__(SYM_GET_COUNT);
unsigned count(void*p){struct NativeList*l=p;return (unsigned)(l->end-l->begin);}
unsigned id(void*) __asm__(SYM_GET_ID);
unsigned id(void*p){return *(((struct NativeList*)p)->cursor);}
void*d1(void*) __asm__("_ZN3pst8services10mediastore6FilterD1Ev");
void*d1(void*p){return p;}
void*d2(void*) __asm__("_ZN3pst8services10mediastore6FilterD2Ev");
void*d2(void*p){return p;}
void*d0(void*) __asm__("_ZN3pst8services10mediastore6FilterD0Ev");
void*d0(void*p){return p;}
