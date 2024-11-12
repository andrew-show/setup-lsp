#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/poll.h>

int g_sig_exit = 0;

void sig_exit(int sig)
{
    g_sig_exit = 1;
}

void escape_puts(char *buf)
{
    while (*buf) {
        switch (*buf) {
        case '$':
        case '*':
        case '`':
        case '!':
        case ' ':
        case '~':
        case '|':
        case '&':
        case '#':
        case '\"':
        case '\'':
        case '\n':
        case '\\':
            putchar('\\');
        default:
            putchar(*buf++);
        }
    }
}

int main(int argc, char *argv[])
{
    struct sockaddr_un addr;

    if (argc < 2) {
        fprintf(stderr, "Usage: args-probe <Path to unix domain socket>\n");
        return 1;
    }

    char *path = argv[1];
    if (strlen(path) >= sizeof(addr.sun_path)) {
        fprintf(stderr, "Size of unix domain socket path exceed the maximum limit!\n");
        return 1;
    }

    signal(SIGINT, sig_exit);
    int fd = socket(AF_UNIX, SOCK_DGRAM, 0);
    if (fd == -1) {
        fprintf(stderr, "Create unix domain socket error!\n");
        return 1;
    }

    int flags = fcntl(fd, F_GETFL, 0);
    flags |= O_NONBLOCK;
    fcntl(fd, F_SETFL, flags);

    addr.sun_family = AF_UNIX;
    strcpy(addr.sun_path, path);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) == -1) {
        fprintf(stderr, "Bind unix domain socket to \'%s\' error\n", path);
        return 1;
    }

    for ( ; ; ) {
        struct pollfd fds;
        fds.fd = fd;
        fds.events = POLLIN;
        fds.revents = 0;
        int nfds = poll(&fds, 1, 1000);
        if (nfds >= 1) {
            char buf[4096];
            int size = recv(fd, buf, sizeof(buf), 0);
            if (size > 0) {
                unsigned int i = 0;
                for ( ; ; ) {
                    escape_puts(&buf[i]);
                    i += strlen(&buf[i]) + 1;
                    if (i >= size)
                        break;
                    putchar(' ');
                }

                putchar('\n');
            }
        } else if (g_sig_exit) {
            break;
        }
    }

    close(fd);
    return 0;
}
