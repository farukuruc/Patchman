#define _GNU_SOURCE
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include "symbols.h"
#include "list-layout.h"

void*ctor(void*,int,void*,int) __asm__(SYM_FILTER_CTOR);
int set(void*,int,unsigned) __asm__(SYM_SET_FILTER);
int full(void*,int,void**,void**) __asm__(SYM_SEARCH_FILTER);
static int object,client;
static void*filter=&object;
static const char*path;
static void preference(const char*value){
 FILE*f=fopen(path,"w");assert(f);assert(fputs(value,f)>=0);assert(fclose(f)==0);
}
static void check(unsigned artist,int a,int b,int c){
 assert(ctor(filter,0,0,0)==filter);assert(!set(filter,5,artist));
 void*out=0;assert(!full(&client,6,&filter,&out));struct NativeList*p=out;
 int expected[]={a,b,c};
 for(unsigned i=0;i<3;i++){
  assert(p->begin[i]==0x81000000u+(unsigned)expected[i]);
  assert(p->initial[i]==(unsigned)('A'+expected[i]-1));
 }
 assert(p->cursor==p->begin);
}
int main(int argc,char**argv){
 assert(argc==2||argc==3);path=argv[1];
 if(argc==3){ /* A-Z / Z-A must still work without the year cache. */
  preference("az\n");check(0x84000019,1,2,3);
  preference("za\n");check(0x84000019,3,2,1);return 0;
 }
 unlink(path);check(0x84000019,2,1,3);
 preference("oldest\n");check(0x84000019,1,2,3);
 preference("newest\n");check(0x84000019,2,1,3);
 preference("az\n");check(0x84000019,1,2,3);
 preference("za\n");check(0x84000019,3,2,1);
 preference("oldest\r\n");check(0x8400001a,2,1,3);
 preference("newest\n");check(0x8400001a,1,2,3);
 preference("oldest\n");check(0x8400001b,1,2,3);
 preference("newest\n");check(0x8400001b,1,2,3);
 preference("oldest\n");check(0x8400001c,1,2,3); /* all years missing */
 const char*invalid[]={"", "wrong\n", "za\nnewest", "too-long-unknown-preference-value", "$(false)"};
 for(unsigned i=0;i<sizeof invalid/sizeof invalid[0];i++){
  preference(invalid[i]);check(0x84000019,2,1,3);
 }
 unlink(path);assert(!symlink("/dev/zero",path));check(0x84000019,2,1,3);unlink(path);
 puts("PASS four live sort modes: repeated queries, missing/invalid preference, unknown years last, ties stable, paired native IDs/initials, cursor preserved");
 return 0;
}
