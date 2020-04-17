FROM osexp2000/ubuntu-with-utils

USER root

WORKDIR /

RUN set -x && apt-get -y update && \
apt-get -y install strace ltrace && \
# perf
apt-get -y install linux-tools-common && \
apt-get -y install python3-pip python3-venv && \
# objdump ...
apt-get -y install binutils && \
# some file utilities
apt-get -y install attr && \
# some tools such as perf-tools need gawk ...
apt-get -y install gawk && \
# need for `mount -t cifs //IP/C /MOUNT_DIR -o user=USER,pass=PASSWD,dom=DOMAIN`
apt-get -y install cifs-utils && \
# some low level tools for container
apt-get -y install runc && \
apt-get -y install expect && \
git clone https://github.com/brendangregg/perf-tools /tools/perf-tools && \
git clone https://github.com/sjitech/docker-geek /tools/docker-geek && \
#
# install docker cli and docker-compose
curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-19.03.8.tgz \
 | tar xz docker/docker && mv docker/docker /usr/bin/docker && rm -fr docker && \
curl -fsSL https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker > /etc/bash_completion.d/docker && \
curl -fsSL https://github.com/docker/compose/releases/download/1.25.5/docker-compose-linux-x86_64 > /usr/bin/docker-compose && chmod +x /usr/bin/docker-compose && \
curl -fsSL https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose && \
#
# config vim: disable swapfile creation due to it can not handle dir such as /proc/1/root/xxx
(echo && echo "set noswapfile") >> ~/.vimrc && \
#
touch /.rootfs-of-docker-geek && \
echo OK

ENV IS_DOCKER_GEEK=1

ENV PATH=$PATH:/tools/perf-tools/bin:/tools/docker-geek/scripts
