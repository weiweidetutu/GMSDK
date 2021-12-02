//
//  TcpSocket.c
//  GMSDK
//
//  Created by yuhan on 2021/11/29.
//

#include "TcpSocket.h"
/*
 创建Socket
 */
int Yh_GetClientFd(int ip_type){
    return  socket(ip_type,SOCK_STREAM, 0);
}
/*
 连接Socket
 **/
int Yh_ConnectSocket(const struct sockaddr * addr,int sock_cli){
    if(connect(sock_cli, addr, sizeof(addr))<0){
        return -1;
    }else{
        return 0;
    }
        
}
/*
关闭Socket
 **/
void Yh_CloseSocket(int fd){
    close(fd);
}

