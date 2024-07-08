#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

static ssize_t advise(const char *buf, size_t size)
{
    char *service = getenv("ARGS_PROBE");
    if (!service)
        return -1;

    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd == -1)
        return -1;

    struct sockaddr_un addr;
    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, service);

    ssize_t nbytes = sendto(fd, buf, size, 0, (struct sockaddr *)&addr, sizeof(addr));
    close(fd);

    return nbytes;
}

static void __attribute__((constructor)) init()
{
    char buf[4096];

    char *pwd = getenv("PWD");
    ssize_t nbytes = strlen(pwd) + 1;
    if (nbytes >= sizeof(buf))
        return;

    strcpy(buf, pwd);
    size_t size = nbytes;

    nbytes = readlink("/proc/self/exe", buf + size, sizeof(buf) - size - 1);
    if (nbytes <= 0)
        return;

    size += nbytes;
    buf[size ++] = '\0';

    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd < 0)
        return;

    nbytes = read(fd, buf + size, sizeof(buf) - size);
    close(fd);

    if (nbytes <= 0)
        return;

    size += nbytes;
    advise(buf, size);
}
