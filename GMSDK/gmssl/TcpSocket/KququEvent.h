//
//  KququEvent.h
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//

#ifndef KququEvent_h
#define KququEvent_h
#include "GMSocket.h"
#include <stdio.h>
#include <ring_buffer.h>
int Yh_Kqeue(int fd,struct kevent *change_event);
int Yh_KqueueOnceLoop(int kq,struct kevent *event,SSL *ssl,ring_buffer *Read, ring_buffer *Write);
#endif /* KququEvent_h */
