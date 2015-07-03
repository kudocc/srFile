//
//  Utility.h
//  srFile
//
//  Created by yuanrui on 15/6/29.
//  Copyright (c) 2015年 KudoCC. All rights reserved.
//

#ifndef __srFile__Utility__
#define __srFile__Utility__

#include <stdio.h>
#include <stdbool.h>
#include <string>
#include <vector>

extern const char FilePathSeparator;

bool localEndianIsLittleEndian();

unsigned short convertNetworkEndianToLocalEndian_us(unsigned short value);
unsigned short convertLocalEndianToNetworkEndian_us(unsigned short value);

unsigned int convertNetworkEndianToLocalEndian_ui(unsigned int value);
unsigned int convertLocalEndianToNetworkEndian_ui(unsigned int value);

bool listdir(const char *path, int level, std::vector<std::string> &vectPath);

/**
 * return false either the path is not exist or it is a file not a directory
 */
bool isDirectoryOnThePath(std::string path);

/**
 * Create all missing directories on the path
 * return false if it occurs error when creating
 */
bool createAllMissingDirectoriesOnThePath(std::string path);

/**
 * get the file size of a opened file
 */
long getFileSize(FILE *file);

#endif /* defined(__srFile__Utility__) */
