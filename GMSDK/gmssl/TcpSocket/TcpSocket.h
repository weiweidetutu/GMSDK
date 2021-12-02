//
//  TcpSocket.h
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//

#ifndef TcpSocket_h
#define TcpSocket_h
#include <netinet/in.h>
#include <sys/socket.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <poll.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <errno.h>
#include <resolv.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#include <stdio.h>
#include <stdio.h>
int Yh_GetClientFd(int ip_type);
int Yh_ConnectSocket(const struct sockaddr * addr,int sock_cli);
void Yh_CloseSocket(int fd);
#endif /* TcpSocket_h */
