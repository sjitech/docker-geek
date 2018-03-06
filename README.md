# docker-geek

Docker container usually have not much tools installed,
so without contaminating the container and host,
how to apply any external tool to the container
- to inspect/change files/network,
- to trace new process's cmdline,
- to trace file access,
- to gdb
- ...
?

I'v managed to do it.

First of first, get the **PID** (init pid) of the container by `docker container inspect CONTAINER_ID_OR_NAME | grep Pid` or more precisely by
```
$ docker container inspect -f '{{.State.Pid}}' CONTAINER_ID_OR_NAME
```

OK, then i'd like to introduce some

## Advanced methods to access files/network of container **directly from host**([*1](#user-content-host))

1. To Access File by File Path Mapping

    Container | <==> | Host
    --------- | ---- | ----
    *A_PATH_IN_CONTAINER* | <==> | /proc/_**PID**_/root/*A_PATH_IN_CONTAINER*

2. To Access Network by [Entering Container's Network Namespace](http://man7.org/linux/man-pages/man1/nsenter.1.html)

    Container | <==> | Host
    --------- | ---- | ----
    *COMMAND ARGS...* | <==> | `nsenter --target` _**PID**_ `--net` *COMMAND ARGS...*

    You can also run `nsenter --target PID --net` first then input command.

- For Example

    ```
    $ docker run -d nginx
    999999999999
    $ docker container inspect -f '{{.State.Pid}}' 999999999999
    8888
    $ vi /proc/8888/root/etc/hosts
    ... same result as vi /etc/hosts in the container ...
    $ nsenter --target 8888 --net
    # iptable -L
    ... container side network info ...
    ```

# Geek's Tool Container

**Put all your tools in it and use it to access target container**.

To eliminate contamination to target container,
start a separate tool container which can be based on any image you want,
such as "ubuntu" or my tool image [osexp2000/ubuntu-with-utils](https://hub.docker.com/r/osexp2000/ubuntu-with-utils/),
and you can install any tool into the tool container (and commit it for later use).

I'v defined a `dockergeek` alias to start a powerful tool container which can
manage any other container and the host itself.

```
alias dockergeek="docker run --rm -it --hostname=geek \
                  --cap-add=SYS_PTRACE --cap-add=SYS_ADMIN --cap-add=NET_ADMIN \
                  --pid=host --network=host --ipc=host --userns=host \
                  -v /var/lib/docker:/var/lib/docker:ro -v /var/run/docker.sock:/var/run/docker.sock -v /usr/bin/docker:/usr/bin/docker:ro \
                  osexp2000/ubuntu-with-utils"
```

And there are also other aliases defined in [docker-geek-aliases](docker-geek-aliases.rc)

## How to access files of a container

- just access /proc/_**PID**_/root/*A_PATH_IN_CONTAINER*

    ```
    $ dockergeek
    root@geek:/# vi /proc/8888/root/A_PATH_IN_CONTAINER
    ```

    This is useful when there are no tools such as vi installed in target container.

## How to access files of the docker host

- just access /proc/1/root/*A_PATH_IN_HOST*

    ```
    $ dockergeek
    root@geek:/# vi /proc/1/root/A_PATH_IN_HOST
    ```

    This is useful when there are no tools such as vi installed in the host.

## How to access network of a container

- just use `nsenter --target PID --net`

    ```
    $ dockergeek
    root@geek:/# nsenter --target=8888 --net
    # iptables -L
    ... network info of the container
    root@geek:/# nsenter --target=8888 --net iptables -L
    ... network info of the container
    ```

    This is useful when there are no tools such as iptables installed in target container.

## How to access network of the docker host

- just use `dockergeek`

    ```
    $ dockergeek
    root@geek:/# iptables -L
    ... network info of the container
    ```

    This is useful when there are no tools such as iptables installed in the hosts.

## How to access files of a docker volume

- just access /var/lib/docker/volumes/_**VOLUME_ID**_/_data

    ```
    $ docker container inspect -f '{{.Mounts}}' 999999999999
    [{volume 666666666666666666666666 /var/lib/docker/volumes/666666666666666666666666/_data /var/lib/mysql local  true }]
    $ dockergeek
    root@geek:/# find /var/lib/docker/volumes/666666666666666666666666/_data -ls
    ... file list ...
    ```

    This helps demystify docker volume and backup.

## How to access files in a stopped container

- just access /var/lib/docker/*STORAGE_DRV_NAME*/*CONTAINER_ID*/diff

    ```
    $ docker container inspect -f '{{.GraphDriver.Data.UpperDir}}' 999999999999
      /var/lib/docker/overlay2/999999999999999999999999/diff
    $ dockergeek
    root@geek:/# find /var/lib/docker/overlay2/999999999999999999999999/diff
    ... file list ...
    ```

    This helps demystify docker storage.

- Then go to [How to find files in a docker image]

## How to access files in a docker image

- The best way is to start the image but let it wait there,
then you `find` /proc/_**PID**_/root/*A_PATH_IN_CONTAINER*

    ```
    $ docker run -d nginx sleep 1234567890
    8888
    $ dockergeek
    root@geek:/# find /proc/8888/root/A_PATH_IN_CONTAINER
    ... file list ...
    ```

- Otherwise, it's also possible get files layer-by-layer

    - Inspect the image to get all layer dirs

    ```
    $ docker image inspect -f '{{.GraphDriver.Data.LowerDir}}' IMAGE_ID_OR_NAME
    /var/lib/docker/overlay2/IMAGE_ID1/diff:/var/lib/docker/overlay2/IMAGE_ID2/diff:...
    $ dockergeek
    root@geek:/# find /var/lib/docker/overlay2/IMAGE_ID1/diff
    ... files changed by this layer ...
    ```

## How to enter the docker host?

- Use [dockerhost](docker-geek-aliases.rc)

    ```
    $ dockerhost
    root@moby:/#
    ```

    Docker for Mac or Windows does not provide docker-machine ssh, so this is useful.

## How to see changed file list of a container

- Use `docker diff` see file changes, even after container stopped

    ```
    $ docker diff 999999999999
    C /etc
    A /run/nginx.pid
    ...
    ```

- or just access /var/lib/docker/*STORAGE_DRV_NAME*/*CONTAINER_ID*/diff

    ```
    $ docker container inspect -f '{{.GraphDriver.Data.UpperDir}}' 999999999999
      /var/lib/docker/overlay2/999999999999999999999999/diff
    $ dockergeek
    root@geek:/# find /var/lib/docker/overlay2/999999999999999999999999/diff
    ... file list ...
    ```

## How to compare two container

- With the path prefix /proc/_**PID**_/root described above,
    you can easily use diff command to compare.

    ```
    $ diff -r /proc/8888/root/A_PATH_IN_CONTAINER /proc/7777/root/A_PATH_IN_CONTAINER
    ```

## How to compare two docker images

- The simplest way to finish this is run the images but let it do nothing,
then go to [How to compare two container]()

    ```
    $ docker run -d DOCKER_IMAGE1 sleep 1234567890
    8888
    $ docker run -d DOCKER_IMAGE2 sleep 1234567890
    7777
    ```

## How to run docker inside docker

- just use `dockergeek`

    ```
    $ dockergeek
    root@geek:/# docker ps
    ...
    ```

## How to trace command line of every new process in a container

- just use [dockertrace](docker-geek-aliases.rc) which in turn use [kernel ftrace](https://github.com/brendangregg/perf-tools)

    ```
    $ dockertrace execsnoop
    ```

- Another way is use PROC_CONNECTOR //todo

## How to trace file activities in a container

- just use [dockertrace](docker-geek-aliases.rc) which in turn use [kernel ftrace](https://github.com/brendangregg/perf-tools)

    ```
    $ dockertrace opensnoop
    ```

## How to strace/gdb into container

- use strace/gdb to debug nsenter and its spawned processes.

    ```
    sudo strace -f nsenter --target=999999999999 --mount --net --uts --ipc --pid COMMAND ARGS...
    ```

    About gdb, same way as above. Just `set follow-fork-mode child` in gdb.

## How to show errno of syscall when use perf-tools

- todo

## How to show target socket address when use `perf trace`

- todo

## Notes

<a name="host"></a>
\*1. Not just the docker host can do this, but also does the docker container which can see host's `/proc`.
