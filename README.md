# docker-geek

A tool suite that lets you freely manipulate files and network of a container, image, or even the host, 
with a tool container.

Although you can use `docker exec` or `nsenter` to run commands on behalf of a container,
sometimes it is painful to do things in a container or its host which does not have many tools installed.

This is why `docker-geek` comes up.

The basic idea is starting a tool container, then
- mount rootfs of the container or host to the tool container
- switch to network namespace of the host or target container

then you can 
- freely use tools in the tool container to manipulate target container or its host.
- install more things without worry of polluting target container or host.

It also provides some extra features, although not necessary normally.
- cross-containers mounting
- view an image a container even it is stopped without starting it

## Usage

### `docker-geek` Run a privileged tool container in the host's network namespace

This tool starts a workbench in which you can freely manipulate files and network of the host.
It will initially do following things:
- it mounts the host's rootfs to `/host-rootfs` 
- it switches to the **host**'s network namespace 
You can further run other docker-geek related commands or even `docker` cli itself in this workbench.  

*Note: the host's rootfs, strictly speaking, means the rootfs of the filesystem namespace of `dockerd`,
 maybe different with the real host. Also, the workbench will also switch to pid,ipc,user namespaces.
 This is also true for other `docker-*-geek` tools.*

```
docker-geek [OPTIONS] [COMMAND [ARGS...]]
```
```
$ docker-geek
root@GEEK:/host-rootfs# ls /host-rootfs
Users    bin  etc   lib       libau.so.2    media  opt   private  root  sbin        srv  tmp  var
Volumes  dev  home  libau.so  libau.so.2.9  mnt    port  proc     run   sendtohost  sys  usr
root@GEEK:/host-rootfs# ip address show
...network info of the host...
```

Note: on Windows Command Prompt, please run:
```
docker run --rm --interactive --tty ^
  --privileged --userns=host --pid=host --ipc=host ^
  --network=host --hostname=GEEK --add-host GEEK:127.0.0.1 ^
  -v /run/desktop/docker.sock:/var/run/docker.sock ^
  -v /run/desktop/docker.pid:/var/run/docker.pid ^
  -v /:/host-rootfs ^
  -v /var/lib/docker:/var/lib/docker:rshared ^
  --workdir /host-rootfs ^
  osexp2000/docker-geek
```

### `docker-container-geek` Start a docker-geek in which mount a container to /rootfs and switch to its network namespace

You can freely manipulate files and network of target container.

```
docker-container-geek [OPTIONS] CONTAINER_ID_OR_NAME [COMMAND [ARGS...]]
```

```
$ docker-container-geek cae89cdb65cd
root@GEEK-cae89cdb65cd:/rootfs# ls /rootfs
...contents of the container's rootfs...
root@GEEK-cae89cdb65cd:/rootfs# ip address show
...network info of target container...
```

### `docker-image-geek` Start a docker-geek in which mount an image to /rootfs (as readonly by default)

You can freely view (or even change) an image or container without running it.

```
docker-image-geek [OPTIONS] IMAGE_ID_OR_NAME [COMMAND [ARGS...]]
```
```
$ docker-image-geek nginx
root@GEEK-cd5239a0906a:/rootfs# 
...contents of the image's rootfs...
```

Notes:
- only works when dockerd is using overlay type of storage.
- by default, the image will be mounted as **readonly**. You can specify `--writable` option to make it writable.
- you can specify a container id or name as the image id or name.

### `docker-mount-image` Mount an image  (as readonly by default)

```
docker-mount-image [OPTIONS] IMAGE_ID_OR_NAME MOUNT_POINT
```
See notes of `docker-image-geek`.

### `docker-mount` Bind-mount a dir or file, among containers and the host

```
docker-mount [OPTIONS] [CONTAINER:]SOURCE_PATH [CONTAINER:]MOUNT_POINT
```
A typical usage is that you might want to mount some files into a running container.

- To mount Windows's C:\\a\\dir_or_file to a container's /a/mountpoint
```
$ docker-mount /host_mnt/c/a/dir_or_file CONTAINER_ID_OR_NAME:/a/mountpoint
```  
- To mount MacOS's /a/dir_or_file to a container's /a/mountpoint
```
$ docker-mount /host_mnt/a/dir_or_file CONTAINER_ID_OR_NAME:/a/mountpoint
```  

## Other Utilities

### `docker-host` Run a command or sh on behalf of the host's dockerd or init process

It enters the host's `dockerd` or init's all namespaces. (Option `-1` means use init process's namespace) 
```
$ docker-host
linuxkit-025000000001:/# ls
Users   bin  etc   lib       libau.so.2    media  opt   private  root  sbin      srv  tmp  var
Volumes  dev  home  libau.so  libau.so.2.9  mnt    port  proc    run  sendtohost  sys  usr
linuxkit-025000000001:/#
linuxkit-025000000001:/# which crictl docker mount.cifs
/usr/bin/crictl
/usr/local/bin/docker
/sbin/mount.cifs
```

### `docker-layers-of-image`, `docker-layers-of-container` Show storage layers of an image or container

```
$ docker-layers-of-image cae89cdb65cd
/var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/diff
/var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d-init/diff
/var/lib/docker/overlay2/80c7824a3012f56122d75283c90b85f2eb733d62889e5bbe956035d77720c554/diff
```
or use it in a pipe:
```
$ docker ps | docker-layers-of-container
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
999999999999        nginx               ...
  layer: /var/lib/docker/overlay2/c6212d8523d5f5250b80c7c6daa29c3d57327b2e9adec345555d2d2fb404fdf1/diff
  layer: /var/lib/docker/overlay2/c6212d8523d5f5250b80c7c6daa29c3d57327b2e9adec345555d2d2fb404fdf1-init/diff
  layer: /var/lib/docker/overlay2/a68ea16a5b16b4c3b8bd659cd53ebe1095ecda2e6fee5ccb5521a156da486cdb/diff
  layer: /var/lib/docker/overlay2/43b4f1b48efb892b151bd3a901c981fc1f03f7e0c3a7e960998d0db0e3a70468/diff
  layer: /var/lib/docker/overlay2/8f74ae7349f0cc8b54cd5201b93bcf89432986bae680b879a12ba0d43a937aa5/diff
cae89cdb65cd        busybox             ...
  layer: /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/diff
  layer: /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d-init/diff
  layer: /var/lib/docker/overlay2/80c7824a3012f56122d75283c90b85f2eb733d62889e5bbe956035d77720c554/diff

$ docker images | docker-layers-of-image
...
```
The result can be further piped to other similar commands of this tool suite. 

Note that the layers will be displayed in order of upper -> lower.

### `docker-rootfs-of-container` Show rootfs of a container

```
$ docker-rootfs-of-container cae89cdb65cd
/var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/merged
```
or use it in a pipe:
```
$ docker ps | docker-rootfs-of-container
CONTAINER ID        IMAGE
999999999999        ...
  rootfs: /var/lib/docker/overlay2/c6212d8523d5f5250b80c7c6daa29c3d57327b2e9adec345555d2d2fb404fdf1/merged
cae89cdb65cd        ...
  rootfs: /var/lib/docker/overlay2/a064c9b385fb9c0eb620ae321e11c38325d4f4b2166ec2fd2e661aa8a0c8049d/merged
```
The result can be further piped to other similar commands of this tool suite. 

### `docker-pid-of-container` Show init process id of a container

```
$ docker-pid-of-container cae89cdb65cd
2788
```
or use it in a pipe:
```
$ docker ps | docker-pid-of-container
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
999999999999        ...
  pid: 2868
cae89cdb65cd        ...
  pid: 2788 
```
The result can be further piped to other similar commands of this tool suite. 

### `docker-cap-of-container` Show capability of the init process of a container

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
or use it in a pipe:
```
$ docker ps | docker-cap-of-container
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
999999999999        ...
  cap: AUDIT_WRITE CHOWN DAC_OVERRIDE FOWNER FSETID KILL MKNOD NET_BIND_SERVICE NET_RAW SETFCAP SETGID SETPCAP SETUID SYS_CHROOT
cae89cdb65cd        ...
  cap: AUDIT_WRITE CHOWN DAC_OVERRIDE FOWNER FSETID KILL MKNOD NET_BIND_SERVICE NET_RAW SETFCAP SETGID SETPCAP SETUID SYS_CHROOT
```
The result can be further piped to other similar commands of this tool suite. 

### `docker-execsnoop` Trace command line of every new process in the host(include in containers)

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

### `docker-opensnoop` Trace file activities in the host(include in containers)

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

### `docker-strace-in-container` Run a program in a container and trace its syscalls

```
docker-strace-in-container CONTAINER_ID_OR_NAME [NSENTER_OPTIONS] COMMAND [ARGS...]
```
```
$ docker-strace-in-container cae89cdb65cd ping -c 1 www.google.com
...
[pid 34323] execve("/bin/ping", ["ping", "-c", "1", "www.google.com"], [/* 4 vars */]) = 0
...
```
