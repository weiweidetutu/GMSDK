//
//  GMWocket.h
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//

#ifndef GMSocket_h
#define GMSocket_h
#include "TcpSocket.h"
#include <stdio.h>
void Yh_ShowCerts(SSL * ssl);

SSL_CTX * Yh_CreateGMMethod(void);

int Yh_LoadCA(char * ca,SSL_CTX * ctx);

int Yh_LoadUserCert(SSL_CTX * ctx,char *cert,char *key);

SSL * Yh_NewSSL(int fd,SSL_CTX *ctx);

int Yh_Read(char *buf,SSL *ssl,int len);

int Yh_Write(char *buf,SSL *ssl,int len);

void Yh_CloseSSL(int fd,SSL*ssl,SSL_CTX*ctx);


#endif /* GMWocket_h */
