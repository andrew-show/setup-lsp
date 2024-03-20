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
    int fd = open("/proc/self/cmdline", O_RDONLY);
    if (fd >= 0) {
        char buf[4096];
        char *pwd = getenv("PWD");
        size_t size = strlen(pwd) + 1;
        if (size < sizeof(buf)) {
            strcpy(buf, pwd);
            ssize_t nbytes = read(fd, buf + size, sizeof(buf) - size);
            if (nbytes > 0) {
                size += nbytes;
                if (size < sizeof(buf)) {
                    advise(buf, size);
                }
            }
        }

        close(fd);
    }
}
