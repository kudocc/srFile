//
//  Utility.cpp
//  srFile
//
//  Created by yuanrui on 15/6/29.
//  Copyright (c) 2015年 KudoCC. All rights reserved.
//

#include "Utility.h"
#include <unistd.h>
#include <sys/types.h>
#include <dirent.h>
#include <stdio.h>
#include <assert.h>
#include <sys/stat.h>
#include <errno.h>

const char FilePathSeparator = '/';

bool localEndianIsLittleEndian()
{
    unsigned short u = 0x1234;
    const char *c = (const char *)&u;
    if (c[0] == 0x12) {
        return false;
    } else {
        return true;
    }
}

unsigned short convertNetworkEndianToLocalEndian_us(unsigned short value)
{
    if (localEndianIsLittleEndian()) {
        char *c = (char *)&value;
        char tmp = c[0];
        c[0] = c[1];
        c[1] = tmp;
        return value;
    } else {
        return value;
    }
}

unsigned short convertLocalEndianToNetworkEndian_us(unsigned short value)
{
    if (localEndianIsLittleEndian()) {
        char *c = (char *)&value;
        char tmp = c[0];
        c[0] = c[1];
        c[1] = tmp;
        return value;
    } else {
        return value;
    }
}

unsigned int convertNetworkEndianToLocalEndian_ui(unsigned int value)
{
    if (localEndianIsLittleEndian()) {
        char *c = (char *)&value;
        char tmp = c[0];
        c[0] = c[3];
        c[3] = tmp;
        tmp = c[1];
        c[1] = c[2];
        c[2] = tmp;
    }
    return value;
}

unsigned int convertLocalEndianToNetworkEndian_ui(unsigned int value)
{
    if (localEndianIsLittleEndian()) {
        char *c = (char *)&value;
        char tmp = c[0];
        c[0] = c[3];
        c[3] = tmp;
        tmp = c[1];
        c[1] = c[2];
        c[2] = tmp;
    }
    return value;
}

bool isFileExist(std::string path, bool &isDirectory)
{
    struct stat st;
    int res = stat(path.c_str(), &st);
    if (res != 0) {
        // error, ENOENT is 2
        printf("stat on path:%s, error %d\n", path.c_str(), errno);
        isDirectory = false;
        return false;
    } else {
        if (st.st_mode & S_IFDIR) {
            isDirectory = true;
        } else {
            isDirectory = false;
        }
        return true;
    }
}

bool isDirectoryOnThePath(std::string path)
{
    struct stat st;
    int res = stat(path.c_str(), &st);
    if (res != 0) {
        // error, ENOENT is 2
        printf("stat on path:%s, error %d\n", path.c_str(), errno);
        return false;
    } else {
        if (st.st_mode & S_IFDIR) {
            return true;
        } else {
            return false;
        }
    }
    return true;
}

bool createDirectoryOnThePath(std::string path)
{
    int res = mkdir(path.c_str(), S_IRWXU);
    if (res == -1) {
        if (errno == EEXIST) {
            // directory exist
            return true;
        } else {
            // error
            printf("mkdir on path:%s, error %d\n", path.c_str(), errno);
            return false;
        }
    } else {
        printf("mkdir success on %s\n", path.c_str());
    }
    return true;
}

bool createAllMissingDirectoriesOnThePath(std::string path)
{
    size_t index = 0;
    while (index < path.length()) {
        size_t pos = path.find_first_of(FilePathSeparator, index);
        if (pos != std::string::npos) {
            index = pos+1;
            std::string subPath = path.substr(0, pos+1);
            bool res = createDirectoryOnThePath(subPath);
            if (!res) {
                return false;
            }
        } else {
            break;
        }
    }
    return true;
}

bool listdir(std::string rootPath, int level, std::vector<std::string> &vectPath)
{
    DIR *dir = NULL;
    struct dirent *entry = NULL;
    
    if (!(dir = opendir(rootPath.c_str())))
        return false;
    if (!(entry = readdir(dir)))
        return false;
    
    do {
        if (entry->d_type == DT_DIR) {
            char path[1024];
            int len = snprintf(path, sizeof(path)-1, "%s%c%s", rootPath.c_str(), FilePathSeparator, entry->d_name);
            path[len] = 0;
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
                continue;
//            printf("%*s[%s]\n", level*2, "", entry->d_name);
            listdir(path, level + 1, vectPath);
        } else {
            std::string pathTemp = rootPath;
            std::string name = entry->d_name;
            pathTemp.append(1, FilePathSeparator);
            pathTemp.append(name);
            vectPath.push_back(pathTemp);
//            printf("%*s- %s\n", level*2, "", entry->d_name);
            printf("%s\n", pathTemp.c_str());
        }
    } while ((entry = readdir(dir)) != NULL);
    closedir(dir);
    return true;
}

long getFileSize(FILE *file)
{
    long cur = ftell(file);
    fseek(file, 0L, SEEK_END);
    long size = ftell(file);
    fseek(file, cur, SEEK_SET);
    return size;
}
