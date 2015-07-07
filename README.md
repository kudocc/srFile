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

First it enumerates all the files and sub directories recursively, for each of them, it send four parts
* 1. length of file name (2 bytes with network endian)
* 2. file size (4 bytes with network endian)
* 3. file name
* 4. file content

After all files finish sending, it close the socket.
