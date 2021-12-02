//
//  KququEvent.c
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//
#include <sys/event.h>
#include "KququEvent.h"
#include "GMSocket.h"
int Yh_Kqeue(int fd,struct kevent *change_event){
    //创建kqueue
    int kq = kqueue();
    if(kq<0){
        return -1;
    }
    //监听可读可写事件
    EV_SET(change_event, fd, EVFILT_READ, EVFILT_WRITE, 0, 0, 0);
    if (kevent(kq, change_event, 1, NULL, 0, NULL) == -1)
    {
        return -2;
    }

    return kq;
}


int Yh_KqueueOnceLoop(int kq,struct kevent *event,SSL *ssl,ring_buffer *Read, ring_buffer *Write){
    
    int  new_events = kevent(kq, NULL, 0, event, 1, NULL);
           if (new_events == -1)
           {
               return -1;
           }

           for (int i = 0; new_events > i; i++)
           {
               printf("amount of new events: %d\n", new_events);
              // int event_fd = event[i].ident;

               if (event[i].flags & EV_EOF)
               {
                   //DisConnect
                   return -100;
               }
               else if (event[i].filter & EVFILT_WRITE)
               {
                 //读取缓冲区，并写入
                   uint8_t writeBuf[1024];
                   memset(writeBuf, 0, sizeof(writeBuf));
                   int len = Ring_Buffer_Read_String(Write, writeBuf, 1024);
                   Yh_Write((char *)writeBuf, ssl, len);
               }

               else if (event[i].filter & EVFILT_READ)
               {
                  //将可读数据写入，读取缓冲区
                   int freeSpace = Ring_Buffer_Get_Lenght(Read);
                   if(freeSpace>1024){
                       uint8_t readBuf[1024];
                       memset(readBuf, 0, sizeof(readBuf));
                      int len = Yh_Read((char*)readBuf, ssl, 1024);
                       if (len>0) {
                           Ring_Buffer_Write_String(Read,readBuf, len);
                       }else{
                           printf("GMSSL Read Fail %d ,Contuine to Transport!\n",len);
                       }
                     
                   }else if(freeSpace>0){
                       uint8_t readBuf[1024];
                       memset(readBuf, 0, sizeof(readBuf));
                      int len = Yh_Read((char*)readBuf, ssl, freeSpace);
                       if (len>0) {
                           Ring_Buffer_Write_String(Read,readBuf, len);
                       }else{
                           printf("GMSSL Read Fail %d ,Contuine to Transport!\n",len);
                       }
                       
                   }else{
                       printf("Buffer Space is full!\n");
                   }
                 
               }
           }
    
    return 0;
}
