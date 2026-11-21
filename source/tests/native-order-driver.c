#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "symbols.h"
#include "list-layout.h"
void*ctor(void*,int,void*,int) __asm__(SYM_FILTER_CTOR);
int clear(void*) __asm__(SYM_FILTER_CLEAR);
int set(void*,int,unsigned) __asm__(SYM_SET_FILTER);
int full(void*,int,void**,void**) __asm__(SYM_SEARCH_FILTER);
int range(void*,int,void**,unsigned,unsigned,void**) __asm__(SYM_SEARCH_RANGE);
void*d1(void*) __asm__("_ZN3pst8services10mediastore6FilterD1Ev");
void mock_mode(int);
static int client,object;
static void*filter=&object;
static struct NativeList*query(int type){void*out=0;assert(full(&client,type,&filter,&out)==0);return out;}
static void choose(unsigned artist){assert(ctor(filter,0,0,0)==filter);assert(set(filter,5,artist)==0);}
int main(int argc,char**argv){
 choose(0x84000019);struct NativeList*p=query(6);
 if(argc>1&&!strcmp(argv[1],"fallback")){assert(p->begin[0]==0x81000001);return 0;}
 assert(p->begin[0]==0x81000002&&p->begin[1]==0x81000001&&p->begin[2]==0x81000003);
 assert(p->initial[0]=='B'&&p->initial[1]=='A'&&p->initial[2]=='C'&&p->cursor==p->begin);
 choose(0x8400001a);p=query(6);assert(p->begin[0]==0x81000001);
 choose(0x8400001b);p=query(6);assert(p->begin[0]==0x81000001&&p->begin[1]==0x81000002);
 choose(0x84000019);p=query(7);assert(p->begin[0]==0x81000001);
 assert(set(filter,6,0x81000001)==0);p=query(6);assert(p->begin[0]==0x81000001);
 assert(clear(filter)==0);assert(set(filter,4,0x82000019)==0);p=query(6);assert(p->begin[0]==0x81000001);
 choose(0x84000019);assert(set(filter,31,0)==9);p=query(6);assert(p->begin[0]==0x81000002);
 choose(0x84000019);void*out=0;assert(range(&client,6,&filter,5,9,&out)==0);p=out;assert(p->begin[0]==0x81000001);
 for(int m=1;m<=3;m++){mock_mode(m);choose(0x84000019);p=query(6);assert(p->begin[0]==0x81000001);if(m==3)assert(p->cursor==p->begin+1);}
 mock_mode(9);assert(full(&client,6,&filter,&out)==9);mock_mode(0);
 int many[700];for(int i=0;i<700;i++){filter=&many[i];choose(0x84000019);p=query(6);assert(p->begin[0]==0x81000002);assert(d1(filter)==filter);}
 filter=&object;choose(0x84000019);p=query(6);
 if(argc==3&&!strcmp(argv[1],"emit")){FILE*f=fopen(argv[2],"w");assert(f);fprintf(f,"{\"ids\":[%u,%u,%u]}\n",p->begin[0],p->begin[1],p->begin[2]);assert(!fclose(f));}
 puts("PASS native years: sorted before return, paired initials, artist-scoped dates, unknown/ties, non-album/composite/range untouched, malformed layout/duplicates rejected, cursor and return statuses preserved, object lifecycle bounded");return 0;
}
