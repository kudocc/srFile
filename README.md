# Introduce

transmit directory/files utility through TCP

**srFile** is a utility used to transmit file or directory through TCP. It works on Mac OS, I'll add a Windows version soon.
There're two commands 'send' and 'recv'.

a) send has two arguments, they indicates where the file/directory is and where file/directory send to respectively.

**send command pattern: send localFilePath/localDirectory remoteAddress:remotePort**

b) receive also has two arguments, they indicates where to keep the file/directory received and the port to listen.

**recv command pattern: recv localDirectoryPath listenPort**

It supports sending the whole directory to peer with the same hierarchy


An example of send, it will send the whole directory "./directoryPath" to 192.168.0.100 who is listenning port 1235
> ./srFile send directoryPath 192.168.0.100:1235

An example of recv, it listens on port 1235 and put all the files or directory in directory "./receiveDirectoryPath"
> ./srFile recv receiveDirectoryPath 1235

# Detail of send

First it enumerates all the files and sub directories recursively, (if you send a file, there is just one file), for each of them, there are five parts:
* 1. path separator of file system which runs the send command ('/' on Mac OS and '\' on Windows)
* 2. length of file name (2 bytes with network endian)
* 3. file size (4 bytes with network endian)
* 4. file name
* 5. file content

Note: If you're sending a file, the file name above is just the file's name. If you're sending a directory, the file name above is the relative pathname which is relative to the directory you specify in srFile command arguments.

After all files finish sending, it closes the socket.

# Detail of receive

On receive side it will receive the data comes from socket until the sender closes the socket. It parses the stream according to the format of [Detail of send](#1). Once it get the file's name, it converts the path separator in the file's name to local separator if the peer path separator is different from the local path separator.
