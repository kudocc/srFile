//
//  main.m
//  srFile
//
//  Created by yuanrui on 15/6/29.
//  Copyright (c) 2015年 KudoCC. All rights reserved.
//
#import <unistd.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import "Utility.h"
#import "PacketMemoryManager.h"

/* send and receive file
 * There're two commands 'send' and 'recv'
 * It supports sending the whole directory to peer with the same hierarchy
 * a) send command pattern: send localFilePath/localDirectory remoteAddress:remotePort
 * b) recv command pattern: recv localDirectoryPath listenPort
 */

/*
 * send format: 1 char to indicate what the path separator ('/' for unix and '\' for windows) is + length of file name (2 byte, big endian) + file size (4 byte, big endian) + file name + file data
 * the file name is a relative file path to the destination directory of recv
 * for example : localDirectory of send is abc, it is a directory, the utlity will send all the content in the directory, file ab.txt is in the directory, we will send abc/ab.txt to the peer. If destination directory of recv is ~/Desktop, then the file should be save at ~/Desktop/abc/ab.txt
 * Note : The localDirectory of send command must locate at the same directory of the utility
 */

#define LISTENQ 5

/**
 * @param localPath the path of file in local
 * @param filePath the path send to peer
 * @return 0 indicates error, otherwise it's the length of sended file
 */
long send(int clientSocket, std::string localPath, std::string filePath);

long recv(int socket, std::string directoryPath);

int main(int argc, const char * argv[]) {
    if (argc != 4) {
        printf("argument count should be 3\n");
        return 0;
    }
    std::string command = argv[1];
    if (command.compare("send") == 0) {
        // send
        std::string filePath = argv[2];
        bool isDirectory = false;
        if (!isFileExist(filePath, isDirectory)) {
            printf("file not exist %s\n", filePath.c_str());
            return 0;
        }
        std::string remote = argv[3];
        size_t pos = remote.find_last_of(':');
        if (pos == std::string::npos) {
            printf("remote server format error, remoteIpAddress:remotePort\n");
            return 0;
        }
        std::string remoteServer = remote.substr(0, pos);
        std::string remotePort = remote.substr(pos+1);
        unsigned short port = (unsigned short)atoi(remotePort.c_str());
        if (port < 1024) {
            printf("local port should be larger than 1024\n");
            return 0;
        }
        int clientfd = 0;
        struct sockaddr_in servaddr;
        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr = inet_addr(remoteServer.c_str());
        servaddr.sin_port = htons(port);
        clientfd = socket (AF_INET, SOCK_STREAM, 0);
        int i = connect(clientfd, (const struct sockaddr *)&servaddr, sizeof(servaddr));
        if (i != 0) {
            printf("connect error\n");
            return 0;
        }
        // send file name length and file name
        if (isDirectory) {
            std::vector<std::string> vect;
            bool res = listdir(filePath, 1, vect);
            if (!res) {
                printf("enumerate file error\n");
                return 0;
            }
            for (std::vector<std::string>::iterator begin = vect.begin(); begin != vect.end(); ++begin) {
                long totalSend = send(clientfd, *begin, *begin);
                if (totalSend > 0) {
                    printf("total send:%ld\n", totalSend);
                } else {
                    printf("send fail on file path:%s\n", begin->c_str());
                    break;
                }
            }
        } else {
            std::string fileName;
            size_t pos = filePath.find_last_of(FilePathSeparator);
            if (pos == std::string::npos) {
                fileName = filePath;
            } else {
                fileName = filePath.substr(pos+1, filePath.length()-pos-1);
            }
            long totalSend = send(clientfd, filePath, fileName);
            if (totalSend > 0) {
                printf("total send:%ld\n", totalSend);
            } else {
                printf("send fail on file path:%s\n", filePath.c_str());
            }
        }
        close(clientfd);
        printf("close socket\n");
    } else if (command.compare("recv") == 0) {
        // recv
        std::string directory = argv[2];
        bool isDirectory = isDirectoryOnThePath(directory);
        if (!isDirectory) {
            printf("directory not exist or it is not directory\n");
            return 0;
        }
        unsigned short port = (unsigned short)atoi(argv[3]);
        if (port < 1024) {
            printf("local port should be larger than 1024\n");
            return 0;
        }
        int listenfd = 0 ;
        int connfd = 0 ;
        socklen_t clilen ;
        struct sockaddr_in cliaddr, servaddr ;
        listenfd = socket (AF_INET, SOCK_STREAM, 0);
        bzero(&servaddr, sizeof(servaddr));
        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr = htonl (INADDR_ANY);
        servaddr.sin_port = htons (port);
        bind(listenfd, (const struct sockaddr *)&servaddr, sizeof(servaddr));
        printf("begin listen on port:%u\n", port) ;
        int rLiten = listen(listenfd, LISTENQ);
        if (rLiten != 0) {
            printf("listen error:%d\n", errno) ;
            return -1 ;
        }
        clilen = sizeof(cliaddr);
        connfd = accept(listenfd, (struct sockaddr *)&cliaddr, &clilen);
        if (connfd < 0) {
            printf("accept error\n");
            return 0;
        } else {
            const char *ip = inet_ntoa(cliaddr.sin_addr) ;
            int port = cliaddr.sin_port ;
            printf("accept from ip:%s, port:%d\n", ip, port) ;
        }
        
        recv(connfd, directory);
        
        close(connfd);
        close(listenfd);
    } else {
        printf("command should be send or recv\n");
    }
    return 0;
}

long send(int clientfd, std::string localPath, std::string filePath)
{
    FILE *file = fopen(localPath.c_str(), "rb");
    if (!file) {
        printf("open file error, %s\n", localPath.c_str());
        return 0;
    }
    
    printf("start to send file %s\n", localPath.c_str());
    
    CPacketMemoryManager packetMemory = CPacketMemoryManager();
    // path separator
    packetMemory.addToBuffer(&FilePathSeparator, 1);
    // file name length
    unsigned short lenFileName = (unsigned short)filePath.length();
    unsigned short lenFileNameNetworkEndian = convertLocalEndianToNetworkEndian_us(lenFileName);
    packetMemory.addToBuffer(&lenFileNameNetworkEndian, sizeof(unsigned short));
    
    // file size
    long lFileSize = (long)getFileSize(file);
    unsigned int uiFileSize = (unsigned int)lFileSize;
    uiFileSize = convertLocalEndianToNetworkEndian_ui(uiFileSize);
    packetMemory.addToBuffer(&uiFileSize, sizeof(uiFileSize));
    
    // file name
    packetMemory.addToBuffer(filePath.c_str(), (unsigned int)filePath.length());
    
    long totalSend = 0;
    size_t sizeRead = 0;
    do {
        unsigned char buffer[2048];
        sizeRead = fread(buffer, 1, sizeof(buffer), file);
        if (sizeRead == 0) {
            // endof file or error
            if (!feof(file)) {
                printf("read error\n");
            }
        } else {
//            printf("fread %zu\n", sizeRead);
            packetMemory.addToBuffer(buffer, (unsigned short)sizeRead);
        }
        if (packetMemory.getUseBufferLength() > 0) {
            bool sendError = false;
            while (1) {
                size_t sizeSend = send(clientfd, packetMemory.getBufferPointer(), packetMemory.getUseBufferLength(), 0);
                if (sizeSend > 0) {
                    packetMemory.removeBuffer((unsigned int)sizeSend);
                    totalSend += sizeSend;
                    break;
                } else {
                    if (errno == EINTR) {
                        continue;
                    } else {
                        sendError = true;
                        // send error
                        break;
                    }
                }
            }
            if (sendError) {
                break;
            }
        }
    } while (sizeRead > 0);
    fclose(file);
    printf("end of sending file %s\n", localPath.c_str());
    return 1;
}

long recv(int connfd, std::string directory)
{
    bool disconnected = false;
    CPacketMemoryManager packetMemory = CPacketMemoryManager();
    while (!disconnected) {
        unsigned int fileSize = 0;
        FILE *file = NULL;
        long writenFileSize = 0;
        long totalRecv = 0;
        while (1) {
            long r = 0 ;
            unsigned char bufferRead[2048] ;
            r = read(connfd, bufferRead, sizeof(bufferRead)) ;
            if (r > 0) {
                totalRecv += r;
                packetMemory.addToBuffer(bufferRead, (unsigned int)r);
                if (file == NULL) {
                    if (packetMemory.getUseBufferLength() > 7) {
                        char *pointer = (char *)packetMemory.getBufferPointer();
                        char peerFileSeparator = *pointer;
                        unsigned short lengthOfFileName = *((unsigned short *)(pointer+1));
                        lengthOfFileName = convertNetworkEndianToLocalEndian_us(lengthOfFileName);
                        unsigned int ui = *(unsigned int *)(pointer+3);
                        fileSize = convertNetworkEndianToLocalEndian_ui(ui);
                        if (packetMemory.getUseBufferLength()-7 >= lengthOfFileName) {
                            // file path
                            char name[100] = {0};
                            memcpy(name, pointer+7, lengthOfFileName);
                            printf("nameLenth:%u, file size:%u, fileName:%s\n", lengthOfFileName, fileSize, name);
                            // open file
                            // directory + file path separator + file name
                            std::string fileName = name;
                            // convert peer separator to local
                            if (FilePathSeparator != peerFileSeparator) {
                                size_t pos = 0;
                                while ((pos = fileName.find_first_of(peerFileSeparator, pos)) != std::string::npos) {
                                    fileName = fileName.replace(pos, 1, 1, FilePathSeparator);
                                    while (pos < fileName.length() && fileName[pos] == peerFileSeparator) {
                                        ++pos;
                                    }
                                }
                            }
                            std::string filePath = directory;
                            if (!(filePath[filePath.length()-1] == FilePathSeparator)) {
                                filePath.append(1, FilePathSeparator);
                            }
                            filePath.append(fileName);
                            bool res = createAllMissingDirectoriesOnThePath(filePath);
                            if (res == false) {
                                printf("can't create missing directory on path:%s\n", filePath.c_str());
                                break;
                            }
                            file = fopen(filePath.c_str(), "wb");
                            if (!file) {
                                printf("open file error, %s\n", filePath.c_str());
                                break;
                            }
                            printf("open file success %s\n", filePath.c_str());
                            packetMemory.removeBuffer(6+lengthOfFileName);
                        }
                    }
                }
                if (file) {
                    if (packetMemory.getUseBufferLength() > 0) {
                        bool finishRecv = false;
                        unsigned int dataSizeNeedWrite = packetMemory.getUseBufferLength();
                        if (packetMemory.getUseBufferLength() >= fileSize-writenFileSize) {
                            finishRecv = true;
                            dataSizeNeedWrite = (unsigned int)(fileSize-writenFileSize);
                        }
                        size_t sizeWrite = fwrite(packetMemory.getBufferPointer(), 1, (size_t)dataSizeNeedWrite, file);
                        if (sizeWrite != dataSizeNeedWrite) {
                            printf("r is %ld, %u, write error, write size:%zu\n", r, dataSizeNeedWrite, sizeWrite);
                            break;
                        } else {
//                            printf("write success, write size:%zu\n", sizeWrite);
                            packetMemory.removeBuffer((unsigned int)sizeWrite);
                            writenFileSize += sizeWrite;
                        }
                        if (finishRecv) {
                            printf("finish receive file successfully\n");
                            fclose(file);
                            file = NULL;
                            writenFileSize = 0;
                        }
                    }
                }
            } else if (r == 0) {
                printf("connection closed by peer\n") ;
                disconnected = true;
                break;
            } else {
                printf("read error %d\n", errno) ;
                disconnected = true;
                break;
            }
        }
        printf("total recv:%ld\n", totalRecv);
    }
    return 0;
}