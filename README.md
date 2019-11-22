# docker-geek

A tool suite that lets you freely manipulate files and network of a container or a host, 
with a tool container.

Although you can use `docker exec` or `nsenter` to run commands on behalf of a container,
sometimes it is painful to do things in a docker container or its host which does not have much tools installed.

This is exactly why `docker-geek` comes up.

The basic idea is starting a tool container, 
- mount rootfs of the container or host into the tool container
- switch to net, ipc, uts namespaces of host or target container optionally

then you can 
- freely use tools in the tool container to manipulate target container or its host.
- install more into it without worry of polluting the target container or host.

It also provide some extra features, although not necessary normally.
- Cross-container volume mapping
- Mount a stopped containers image without starting it

## Installation && Quick Start

Let's start the workbench so from there you can further run other commands of this tool suite.

**You might just want to have a try without downloading this repo nor installing anything to your host**, so just run

*For Bash:*
```
docker run --rm -it \
    --privileged --userns=host \
    --pid=host --network=host --ipc=host \
    --hostname=GEEK --add-host GEEK:127.0.0.1 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/run/docker.pid:/var/run/docker.pid \
    -v /var/lib/docker:/var/lib/docker:rshared \
    -v /:/host-rootfs \
    --workdir /host-rootfs \
    osexp2000/docker-geek
```
*For Windows Cmd:*
```
docker run --rm -it ^
    --privileged --userns=host ^
    --pid=host --network=host --ipc=host ^
    --hostname=GEEK --add-host GEEK:127.0.0.1 ^
    -v /var/run/docker.sock:/var/run/docker.sock ^
    -v /var/run/docker.pid:/var/run/docker.pid ^
    -v /var/lib/docker:/var/lib/docker:rshared ^
    -v /:/host-rootfs ^
    --workdir /host-rootfs ^
    osexp2000/docker-geek
```
Then you got a workbench with workding dir pointing to rootfs of the host.
```
root@GEEK:/host-rootfs#
```
**You can use docker commands and other utilities of this tool suite there.**

For Bash users who want to call these commands directly from host, just can clone this repo, 
and add the `scripts` dir into your PATH into your Bash settings.


The docker image [`osexp2000/docker-geek`](Dockerfile) consists of all necessary stuff. 
most utilities are baked into `/usr/local/bin` of the image.
```
docker-geek
docker-container-geek
docker-container-geek-ns
docker-image-geek

docker-mount-image
docker-mount-cifs
docker-mount-local-win-share
docker-bind-mount

docker-umount

docker-host
docker-host1

docker-execsnoop
docker-opensnoop
docker-strace-cmd-in-container

docker-layers-of
docker-pid-of-container
docker-cap-of-container
docker-rootfs-of-container
```

Note:
- You can use docker client in this workbench and most tools of this suite.
- You can call commands of this suite from each other.
- You can save changes made to the tool container locally with `docker commit THE_RUNNING_DOCKER_GEEK_CONTAINER_ID osexp2000/docker-image`

## Usage

### `docker-geek`: freely manipulate files and network of the host, also as a entry to this workbench 

This tool starts a tool container, and 
- map host's rootfs into `/host-rootfs`
- switch to net,ipc,uts namespaces of **host**

You can further run other commands in this workbench.

```
docker-geek [OPTIONS] [CMD [ARGS...]]
```
```
$ docker-geek
root@GEEK:/host-rootfs# ls /host-rootfs
Users    bin  etc   lib       libau.so.2    media  opt   private  root  sbin        srv  tmp  var
Volumes  dev  home  libau.so  libau.so.2.9  mnt    port  proc     run   sendtohost  sys  usr
root@GEEK:/host-rootfs# ip address show
...network info of the host...
```

Note: more accurately, this tool enter PID 1's net,ipc,uts namespaces, it may still be different
with `dockerd`'s namespaces which pid is not 1.

### `docker-container-geek`: freely manipulate files of a container

This tool starts a tool container, and 
- map target container's rootfs into `/rootfs`
- map host's rootfs into `/host-rootfs`
- switch to net,ipc,uts namespaces of **host**

```
docker-container-geek [OPTIONS] CONTAINER_ID_OR_NAME [CMD [ARGS...]]
```

```
$ docker-container-geek cae89cdb65cd
root@GEEK-cae89cdb65cd:/rootfs# ls /rootfs
bin  dev  etc  home  proc  root  sys  tmp  usr  var
root@GEEK-cae89cdb65cd:/rootfs# ls /host-rootfs
Users    bin  etc   lib       libau.so.2    media  opt   private  root  sbin        srv  tmp  var
Volumes  dev  home  libau.so  libau.so.2.9  mnt    port  proc     run   sendtohost  sys  usr
```

### `docker-container-geek-ns`: freely manipulate files and network of a container

Much like `docker-container-geek`, except that it switch to namespaces of target container.

This tool starts a tool container, and 
- map target container's rootfs into `/rootfs`
- map host's rootfs into `/host-rootfs`
- switch to pid,net,ipc,uts namespaces of **target container**

```
docker-container-geek-ns [OPTIONS] CONTAINER_ID_OR_NAME [CMD [ARGS...]]
```

```
$ docker-container-geek-ns cae89cdb65cd
root@GEEK-cae89cdb65cd:/rootfs# ip address show
...network info of the target container...
```

### `docker-image-geek`: view a docker image or container without run it

This tool starts a tool container, and 
- mount docker image or container into `/rootfs` as **readonly** (*currently only overlay type of storage, not yet aufs or others*)
- map host's rootfs into `/host-rootfs`
- switch to net,ipc,uts namespaces of **host**

```
docker-image-geek [OPTIONS] IMAGE_ID_OR_NAME [CMD [ARGS...]]
```
NOTE: you can specify a container as image. 

```
$ docker-image-geek nginx
root@GEEK-cd5239a0906a:/rootfs# 
root@GEEK-cd5239a0906a:/rootfs# ls /rootfs
bin dev ...
```

you can further run `tar -cz PATH` to tgz files from the image to stdout then `tar -xz` to extract to local.
```
$ docker-image-geek nginx tar -cz bin | tar -xz -C /tmp
```   
this will copy bin dir from the nginx image to /tmp/ 

### `docker-strace-cmd-in-container`: run a command in strace mode in a container

Run `nsenter` to attach to target container then run specified command, trace all these processes.

```
docker-strace-cmd-in-container CONTAINER_ID_OR_NAME [NSENTER_OPTIONS] COMMAND [ARGS...]
```
```
$ docker-strace-cmd-in-container cae89cdb65cd ping -c 1 www.google.com
...
[pid 34323] execve("/bin/ping", ["ping", "-c", "1", "www.google.com"], [/* 4 vars */]) = 0
...
```

### `docker-execsnoop`: trace command line of every new process in the host(include in containers)

```
$ docker-execsnoop [...arguments of execsnoop...]
```
```
$ docker-execsnoop
Tracing exec()s. Ctrl-C to end.
Instrumenting sys_execve
   PID   PPID ARGS
 17603  17601 cat -v trace_pipe
 17602  17598 gawk -v o=1 -v opt_name=0 -v name= -v opt_duration=0 [...]
```

Then you use grep to filter out things of target container.

### `docker-opensnoop`: trace file activities in the host(include in containers)

```
$ docker-opensnoop [...arguments of opensnoop...]
```
```
$ docker-opensnoop
Tracing open()s. Ctrl-C to end.
COMM             PID      FD FILE
opensnoop        17605   0x3
opensnoop        17610   0x3 /etc/ld.so.cache
opensnoop        17610   0x3 /lib/x86_64-linux-gnu/libc.so.6
opensnoop        17609   0x3 /etc/ld.so.cache
```

Then you use grep to filter out things of target container.

### `docker-bind-mount` bind-mount files into a container or among container and host

sometimes you forgot to configure volume mount for a container and just started the container, 
for some reason, you might want to mount some files into it.

```
docker-bind-mount [OPTIONS] [CONTAINER:]SOURCE_PATH [CONTAINER:]TARGET_PATH
```
you want to map second containers cae89cdb65cd's /dir1 to first's /xxx
```
$ docker-bind-mount CONTAINER_ID1:/dir1 CONTAINER_ID2:/xxx
```

You can also mount file or dir from a container to a host or reverse
```
docker-bind-mount CONTAINER_ID_OR_NAME:/CONTAINER_DIR /HOST_DIR
```
```
docker-bind-mount /HOST_DIR CONTAINER_ID_OR_NAME:/CONTAINER_DIR
```

### `docker-mount-image`: Persistently mount a docker image or container as readonly

```
docker-mount-image ID_OR_NAME MOUNT_POINT
```

```
$ docker-mount-image cae89cdb65cd
root@GEEK:/host-rootfs# ls /xxx
bin  dev  etc  home  proc  root  sys  tmp  usr  var
```

### `docker-mount-local-win-share`: Mount windows drive(such as C$) into host at /mnt/C$

This is specially useful for `Docker for Windows` when it complains firewall detected, due to
various reason, notably in a enterprise environment where every PC runs a Anti-Virus soft.

```
docker-mount-local-win-share DRIVE_LETTER USER DOMAIN
```
```
docker-mount-local-win-share C$ MY_USER MY_DOMAIN
... enter password ...
mounted at /mnt/C$
```

to unmount, `docker-geek umount /mnt/C$`

For detail, see 
- https://github.com/docker/for-win/issues/466#issuecomment-398305463
- https://github.com/docker/for-win/issues/466#issuecomment-416682825 

### `docker-mount-cifs`: Mount windows drive(such as C) into host at /mnt/C

This is specially useful for `Docker for Windows` when it complains firewall detected, due to
various reason, notably in a enterprise environment where every PC runs a Anti-Virus soft.

```
docker-mount-cifs SHARE_UNC USER DOMAIN
```
```
docker-mount-cifs //192.168.1.2/share user domain
... enter password ...
mounted at /mnt/192.168.1.2/share
```

to unmount, `docker-geek umount /mnt/192.168.1.2/share` 

### `docker-host`: enter the `dockerd`

enter dockerd's all namespaces.
```
$ docker-host
linuxkit-025000000001:/# ls
Users	 bin  etc   lib       libau.so.2    media  opt	 private  root	sbin	    srv  tmp  var
Volumes  dev  home  libau.so  libau.so.2.9  mnt    port  proc	  run	sendtohost  sys  usr
linuxkit-025000000001:/#
linuxkit-025000000001:/# which crictl docker mount.cifs
/usr/bin/crictl
/usr/local/bin/docker
/sbin/mount.cifs
```

### `docker-host1`: enter the host

enter pid 1's all namespaces.
```
$ docker-host1
linuxkit-025000000001:/# ls
EFI         boot        dev         home        lib         mnt         proc        run         srv         tmp         var
bin         containers  etc         init        media       opt         root        sbin        sys         usr
```

### `docker-layers-of`: show image layers of a container or image easily

```
$ docker-layers-of cae89cdb65cd
/var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/diff
/var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d-init/diff
/var/lib/docker/overlay2/80c7824a3012f56122d75283c90b85f2eb733d62889e5bbe956035d77720c554/diff
```
or use it in pipe:
```
$ docker ps | docker-layers-of
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
17c5d7eafa20        nginx               ...
  layer: /var/lib/docker/overlay2/c6212d8523d5f5250b80c7c6daa29c3d57327b2e9adec345555d2d2fb404fdf1/diff
  layer: /var/lib/docker/overlay2/c6212d8523d5f5250b80c7c6daa29c3d57327b2e9adec345555d2d2fb404fdf1-init/diff
  layer: /var/lib/docker/overlay2/a68ea16a5b16b4c3b8bd659cd53ebe1095ecda2e6fee5ccb5521a156da486cdb/diff
  layer: /var/lib/docker/overlay2/43b4f1b48efb892b151bd3a901c981fc1f03f7e0c3a7e960998d0db0e3a70468/diff
  layer: /var/lib/docker/overlay2/8f74ae7349f0cc8b54cd5201b93bcf89432986bae680b879a12ba0d43a937aa5/diff
cae89cdb65cd        busybox             ...
  layer: /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/diff
  layer: /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d-init/diff
  layer: /var/lib/docker/overlay2/80c7824a3012f56122d75283c90b85f2eb733d62889e5bbe956035d77720c554/diff

$ docker images | docker-layers-of
...
```
The result can be further piped to other similar commands of this tool suite. 

### `docker-rootfs-of-container`: show path of rootfs of a container

```
$ docker-rootfs-of-container cae89cdb65cd
/var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/merged
```
or use it in pipe:
```
$ docker ps | docker-rootfs-of-container
CONTAINER ID        IMAGE
17c5d7eafa20        ...
  rootfs: /var/lib/docker/overlay2/c6212d8523d5f5250b80c7c6daa29c3d57327b2e9adec345555d2d2fb404fdf1/merged
cae89cdb65cd        ...
  rootfs: /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/merged
```
The result can be further piped to other similar commands of this tool suite. 

### `docker-pid-of-container`: show init process id of a container

```
$ docker-pid-of-container cae89cdb65cd
2788
```
or use it in pipe:
```
$ docker ps | docker-pid-of-container
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
17c5d7eafa20        ...
  pid: 2868
cae89cdb65cd        ...
  pid: 2788 
```
The result can be further piped to other similar commands of this tool suite. 

### `docker-cap-of-container`: show process capabilities of a container

```
$ docker-cap-of-container cae89cdb65cd
AUDIT_WRITE
CHOWN
DAC_OVERRIDE
FOWNER
FSETID
KILL
MKNOD
NET_BIND_SERVICE
NET_RAW
SETFCAP
SETGID
SETPCAP
SETUID
SYS_CHROOT
$ docker-cap-of-container cae89cdb65cd -f
00000000a80425fb=[AUDIT_WRITE CHOWN DAC_OVERRIDE FOWNER FSETID KILL MKNOD NET_BIND_SERVICE NET_RAW SETFCAP SETGID SETPCAP SETUID SYS_CHROOT]
$ docker-cap-of-container cae89cdb65cd -n
00000000a80425fb
```
or use it in pipe:
```
$ docker ps | docker-cap-of-container
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
17c5d7eafa20        ...
  cap: AUDIT_WRITE CHOWN DAC_OVERRIDE FOWNER FSETID KILL MKNOD NET_BIND_SERVICE NET_RAW SETFCAP SETGID SETPCAP SETUID SYS_CHROOT
cae89cdb65cd        ...
  cap: AUDIT_WRITE CHOWN DAC_OVERRIDE FOWNER FSETID KILL MKNOD NET_BIND_SERVICE NET_RAW SETFCAP SETGID SETPCAP SETUID SYS_CHROOT
```
The result can be further piped to other similar commands of this tool suite. 

## Other Tips

### How to access files of a container directly from its host

E.g., You have a running container ID 17c5d7eafa20, you want to vi its file /some_dir/some_file.
(*for a stopped container, I'll describe it later*)

- Method1: via **MOUNTED_CONTAINER_DIR** prefix

    ```
    $ docker container inspect -f '{{.GraphDriver.Data.MergedDir}}' 17c5d7eafa20
    /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/merged
    $ vi /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/merged/some_dir/some_file
    ```

- Method2: via `/proc/CONTAINER_PID/root/` prefix

    ```
    $ docker inspect -f '{{.State.Pid}}' cae89cdb65cd
    2788
    $ vi /proc/2788/root/some_dir/some_file
    ```

Note: /proc/CONTAINER_PID/root/ is not a cwd-able dir thus it will cause some tool complains about "(unreachable)"

### How to access files of a docker volume

just access /var/lib/docker/volumes/_**VOLUME_ID**_/_data

```
$ docker container inspect -f '{{.Mounts}}' 999999999999
[{volume 666666666666666666666666 /var/lib/docker/volumes/666666666666666666666666/_data /var/lib/mysql local  true }]
```

### How to access files in a stopped container without `docker cp` out

just access /var/lib/docker/*STORAGE_DRV_NAME*/*CONTAINER_ID*/diff

```
$ docker container inspect -f '{{.GraphDriver.Data.UpperDir}}' 999999999999
  /var/lib/docker/overlay2/999999999999999999999999/diff
```

### How to compare files in two containers

With the path prefix `/proc/CONTAINER_PID/root/` described above,
you can easily use diff command to compare.

```
root@GEEK diff -r /proc/8888/root/PATH_IN_CONTAINER /proc/7777/root/PATH_IN_CONTAINER
```

### How to compare files in two docker images

The simplest way to finish this is run the images but let it do nothing,
then go to [How to compare two container]()

```
$ docker run -d DOCKER_IMAGE1 sleep 1234567890
8888
$ docker run -d DOCKER_IMAGE2 sleep 1234567890
7777
```

Another way is use `docker-image-geek` to mount image into dir and compare.

## todo

- How to show errno of syscall when use perf-tools
- How to show target socket address when use `perf trace`
- How to install utilities such as sysdig which depends on host's kernel version?
