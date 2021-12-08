//
//  GMWocket.c
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//
#include "GMSocket.h"
/*
 获取服务端证书信息
 **/
void Yh_ShowCerts(SSL * ssl)
{
    X509 * cert;
    char * line;
    cert = SSL_get_peer_certificate(ssl);
    if (cert != NULL)
    {
        printf("数字证书信息:\n");
        line = X509_NAME_oneline(X509_get_subject_name(cert), 0, 0);
        printf("证书: %s\n", line);
        free(line);
        line = X509_NAME_oneline(X509_get_issuer_name(cert), 0, 0);
        printf("颁发者: %s\n", line);
        free(line);
        X509_free(cert);
    }
    else
    {
        printf("无证书信息！\n");
    }
}
/*
 创建国密SSL_CTX
 err null
 **/
SSL_CTX * Yh_CreateGMMethod(void){
    /* SSL 库初始化*/
    SSL_library_init();
    /* 载入所有SSL 算法*/
    OpenSSL_add_all_algorithms();
    /* 载入所有SSL 错误消息*/
    SSL_load_error_strings();
    /* 采用国密产生一个SSL_CTX**/
    return SSL_CTX_new(GMTLS_client_method());
}
/*
 加载CA证书
 -1 CA加载失败
  **/
int Yh_LoadCA(char * ca,SSL_CTX * ctx){
    SSL_CTX_set_verify(ctx,SSL_VERIFY_PEER,NULL);
    if(SSL_CTX_load_verify_locations(ctx, ca, NULL)<0){
        SSL_CTX_free(ctx);
        return -1;
    }
    return 0;
}
/*
 加载用户PEM证书
 -1 cert 加载失败
 -2 key 加载失败
 -3 私钥校验失败
 **/
int Yh_LoadUserCert(SSL_CTX * ctx,char *cert,char *key){
    if(SSL_CTX_use_certificate_file(ctx, cert, SSL_FILETYPE_PEM)<0){
        SSL_CTX_free(ctx);
        return -1;
    }
    if(SSL_CTX_use_PrivateKey_file(ctx, key, SSL_FILETYPE_PEM)<0){
        SSL_CTX_free(ctx);
        return -2;
    }
    if (!SSL_CTX_check_private_key(ctx))
    {
        SSL_CTX_free(ctx);
        return -3;
    }
    return 0;
}
/**
 产生SSL连接
 -NULL SSL连接建立失败
 */
SSL * Yh_NewSSL(int fd,SSL_CTX *ctx){
    //产生一个新的SSL
    SSL*ssl= SSL_new(ctx);
    //设置文件描述符
    SSL_set_fd(ssl, fd);
    if(SSL_connect(ssl)<=0){
        ERR_print_errors_fp(stderr);
        SSL_shutdown(ssl);
        SSL_free(ssl);
        SSL_CTX_free(ctx);
        return NULL;
    }
    return ssl;
}

int Yh_Read(char *buf,SSL *ssl,int len){
    return  SSL_read(ssl, buf, len);
}

int Yh_Write(char *buf,SSL *ssl,int len){
    return  SSL_write(ssl, buf, len);
}

/*
 关闭SSL连接
 **/
void Yh_CloseSSL(int fd,SSL*ssl,SSL_CTX*ctx){
    Yh_CloseSocket(fd);
    SSL_shutdown(ssl);
    SSL_free(ssl);
    SSL_CTX_free(ctx);
}
