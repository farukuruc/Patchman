#define _GNU_SOURCE
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <time.h>
#include <errno.h>
#include "cache.h"
static const char *empty_js=".pragma library\nfunction year(artist,album){return \"\"}\n";
static void string(FILE*f,const char*s){
 fputc('"',f);
 for(const unsigned char*p=(const unsigned char*)s;*p;p++){
  if(*p=='"'||*p=='\\'){fputc('\\',f);fputc(*p,f);}
  else if(*p<32)fprintf(f,"\\u%04x",*p);
  else if(p[0]==0xe2&&p[1]==0x80&&(p[2]==0xa8||p[2]==0xa9)){fprintf(f,"\\u202%c",p[2]==0xa8?'8':'9');p+=2;}
  else fputc(*p,f);
 }
 fputc('"',f);
}
static int expired(void*start){struct timespec now;clock_gettime(CLOCK_MONOTONIC,&now);return now.tv_sec-*(time_t*)start>=3;}
static int path(char*out,size_t n,const char*dir,const char*name){return snprintf(out,n,"%s/%s",dir,name)<(int)n;}
static int save(const char*dir,const char*name,const void*data,size_t size){
 char dest[4096],temp[4096];if(!path(dest,sizeof dest,dir,name)||snprintf(temp,sizeof temp,"%s.new",dest)>=(int)sizeof temp)return -1;
 int fd=open(temp,O_WRONLY|O_CREAT|O_TRUNC|O_CLOEXEC|O_NOFOLLOW,0600);if(fd<0)return -1;
 struct stat st;int bad=fstat(fd,&st)||!S_ISREG(st.st_mode);
 size_t at=0;while(!bad&&at<size){ssize_t n=write(fd,(const char*)data+at,size-at);if(n<=0)bad=1;else at+=(size_t)n;}
 if(fchmod(fd,0666)||fsync(fd))bad=1;if(close(fd))bad=1;
 if(bad||rename(temp,dest)){unlink(temp);return -1;}return 0;
}
static void photo(FILE*f,const char*directory,const char*artist,unsigned id,unsigned*count){
 char filename[16384];size_t n=0;
 for(const unsigned char*p=(const unsigned char*)artist;*p;p++){
  if(strchr("<>:\"/\\|?*%",*p)||*p<32){if(n+3>=sizeof filename)return;snprintf(filename+n,4,"%%%02X",*p);n+=3;}
  else {if(n+1>=sizeof filename)return;filename[n++]=(char)*p;}
 }
 filename[n]=0;
 const char*extensions[]={".jpg",".png",".JPG",".PNG"};char candidate[32768];struct stat st;
 for(unsigned i=0;i<sizeof extensions/sizeof *extensions;i++){
  if(snprintf(candidate,sizeof candidate,"%s/%s%s",directory,filename,extensions[i])>=(int)sizeof candidate)return;
  if(lstat(candidate,&st)||!S_ISREG(st.st_mode)||st.st_size<1||st.st_size>8*1024*1024)continue;
  if((*count)++)fputc(',',f);fprintf(f,"\"$%u\":\"file://",id);
  for(const unsigned char*p=(const unsigned char*)candidate;*p;p++){
   unsigned char c=*p;if((c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9')||strchr("/-._~",c))fputc(c,f);else fprintf(f,"%%%02X",c);
  }
  fputc('"',f);return;
 }
}
static int build(const char*dbpath,const char*dir,const char*photos){
 sqlite3*db=NULL;sqlite3_stmt*st=NULL;struct timespec start;clock_gettime(CLOCK_MONOTONIC,&start);
 int ok=0,rc=sqlite3_open_v2(dbpath,&db,SQLITE_OPEN_READONLY|SQLITE_OPEN_NOMUTEX,NULL);
 if(rc!=SQLITE_OK)goto end;
 sqlite3_busy_timeout(db,150);sqlite3_progress_handler(db,10000,expired,&start.tv_sec);
 const char*sql="SELECT ob.albumartist_id,ob.album_id,aa.value,MIN(CASE WHEN CAST(ry.value AS INTEGER) BETWEEN 1000 AND 2999 THEN CAST(ry.value AS INTEGER) END),MAX(CASE WHEN CAST(ry.value AS INTEGER) BETWEEN 1000 AND 2999 THEN CAST(ry.value AS INTEGER) END) FROM object_body ob JOIN albumartists aa ON aa.id=ob.albumartist_id LEFT JOIN releaseyears ry ON ry.id=ob.releaseyear_id WHERE ob.media_type=1 AND ob.albumartist_id BETWEEN 1 AND 16777215 AND ob.album_id BETWEEN 1 AND 16777215 GROUP BY ob.albumartist_id,ob.album_id ORDER BY ob.albumartist_id,ob.album_id";
 if(sqlite3_prepare_v2(db,sql,-1,&st,NULL)!=SQLITE_OK)goto end;
 struct YearRecord*records=calloc(YEAR_LIMIT,sizeof *records);if(!records)goto end;
 char*names=NULL,*years=NULL,*images=NULL;size_t names_size=0,years_size=0,images_size=0;
 FILE*nf=open_memstream(&names,&names_size),*yf=open_memstream(&years,&years_size),*pf=open_memstream(&images,&images_size);
 if(!nf||!yf||!pf){if(nf)fclose(nf);if(yf)fclose(yf);if(pf)fclose(pf);free(names);free(years);free(images);free(records);goto end;}
 unsigned count=0,artists=0,last_artist=0,photo_count=0;
 struct stat photo_dir;int root_rc=stat(photos,&photo_dir),root_error=root_rc?errno:0;
 int have_photos=!root_rc&&S_ISDIR(photo_dir.st_mode);
 printf("Artist photos internal-flat-v1: root=%s available=%d errno=%d\n",photos,have_photos,root_error);
 while((rc=sqlite3_step(st))==SQLITE_ROW){
  if(count>=YEAR_LIMIT){rc=SQLITE_TOOBIG;break;}
  uint32_t artist=0x84000000u+(uint32_t)sqlite3_column_int64(st,0),album=0x81000000u+(uint32_t)sqlite3_column_int64(st,1);
  const char*name=(const char*)sqlite3_column_text(st,2);if(!name||strlen(name)>4096){rc=SQLITE_TOOBIG;break;}
  int low=sqlite3_column_int(st,3),high=sqlite3_column_int(st,4);unsigned year=low>=1000&&low<=2999&&low==high?(unsigned)low:0;
  records[count]=(struct YearRecord){artist,album,year};
  if(artist!=last_artist){if(have_photos)photo(pf,photos,name,artist,&photo_count);if(artists++)fputc(',',nf);fputc('"',nf);fputc('$',nf);/* JSON-escape the name without nesting quotes. */
   char*encoded=NULL;size_t encoded_size=0;FILE*ef=open_memstream(&encoded,&encoded_size);
   if(!ef){rc=SQLITE_NOMEM;break;}string(ef,name);if(fclose(ef)){free(encoded);rc=SQLITE_IOERR;break;}
   fwrite(encoded+1,1,encoded_size-2,nf);fprintf(nf,"\":%u",artist);free(encoded);last_artist=artist;
  }
  if(count)fputc(',',yf);fprintf(yf,"\"$%u:%u\":%u",artist,album,year);count++;
  if(ftell(nf)+ftell(yf)+ftell(pf)>1024*1024){rc=SQLITE_TOOBIG;break;}
 }
 int bad=ferror(nf)||ferror(yf)||ferror(pf);if(fclose(nf))bad=1;if(fclose(yf))bad=1;if(fclose(pf))bad=1;
 if(rc==SQLITE_DONE&&!bad){
  struct YearHeader header={YEAR_MAGIC,1,count,year_checksum(records,count*sizeof *records)};
  size_t bytes=sizeof header+count*sizeof *records;unsigned char*bin=malloc(bytes);char*js=NULL;size_t js_size=0;FILE*jf=open_memstream(&js,&js_size);
  if(bin&&jf){
   memcpy(bin,&header,sizeof header);memcpy(bin+sizeof header,records,count*sizeof *records);
   fprintf(jf,".pragma library\nvar artistIds={%s}\nvar years={%s}\nvar artistPhotos={%s}\nfunction photo(name){var id=artistIds[\"$\"+name],v=artistPhotos[\"$\"+id];return typeof v===\"string\"?v:\"\"}\nfunction year(artist,album){var id=artistIds[\"$\"+artist],n=Number(album),v=years[\"$\"+id+\":\"+n];return typeof v===\"number\"&&v>=1000&&v<=2999?String(v):\"\"}\n",names,years,images);
   int js_bad=ferror(jf);if(fclose(jf))js_bad=1;jf=NULL;
   if(!js_bad&&!save(dir,"album-years.bin",bin,bytes)&&!save(dir,"AlbumYearCache.js",js,js_size)){ok=1;printf("Native album-year snapshot ready: %u artist/album pairs, %u optional artist photos\n",count,photo_count);}
  }
  if(jf)fclose(jf);free(bin);free(js);
 }
 free(names);free(years);free(images);free(records);
end:
 if(st)sqlite3_finalize(st);if(db)sqlite3_close(db);
 if(!ok){save(dir,"AlbumYearCache.js",empty_js,strlen(empty_js));fprintf(stderr,"Native album-year snapshot unavailable; retain Sony order\n");}
 return ok?0:1;
}
int main(int argc,char**argv){if((argc!=4&&argc!=5)||strcmp(argv[1],"once")){fprintf(stderr,"usage: album-year-cache once DB RUNTIME [PHOTO_DIR]\n");return 2;}alarm(5);return build(argv[2],argv[3],argc==5?argv[4]:"/contents/ARTIST-PHOTOS");}
