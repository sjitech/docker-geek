FROM scratch as util-linux-part-dist

COPY --from=osexp2000/util-linux-static /usr/bin/nsenter /dist/usr/bin/
COPY --from=osexp2000/util-linux-static /usr/share/bash-completion/completions/nsenter /dist/etc/bash_completion.d/
COPY --from=osexp2000/util-linux-static /usr/share/man/man1/nsenter.1 ./distusr/share/man/man1/

COPY --from=osexp2000/util-linux-static /usr/bin/lsns /dist/usr/bin/
COPY --from=osexp2000/util-linux-static /usr/share/bash-completion/completions/lsns /dist/etc/bash_completion.d/
COPY --from=osexp2000/util-linux-static /usr/share/man/man8/lsns.8 /dist/usr/share/man/man8/

COPY --from=osexp2000/util-linux-static /bin/mount /dist/bin/
COPY --from=osexp2000/util-linux-static /usr/share/bash-completion/completions/mount /dist/etc/bash_completion.d/
COPY --from=osexp2000/util-linux-static /usr/share/man/man8/mount.8 ./distusr/share/man/man8/

COPY --from=osexp2000/util-linux-static /bin/umount /dist/bin/
COPY --from=osexp2000/util-linux-static /usr/share/bash-completion/completions/umount /dist/etc/bash_completion.d/
COPY --from=osexp2000/util-linux-static /usr/share/man/man8/umount.8 ./distusr/share/man/man8/

COPY ./scripts /dist/usr/local/bin/
COPY ./scripts-linux /dist/usr/local/bin/

# copy nsenter-host related scripts
COPY --from=osexp2000/nsenter-host /usr/local/bin/nsenter-* /dist/usr/local/bin/

# copy bind-mount related scripts
COPY --from=osexp2000/bind-mount /usr/local/bin/bind-mount /dist/usr/local/bin/

###############################################################################

FROM osexp2000/ubuntu-with-utils

USER root

WORKDIR /

RUN apt-get -y update && \
#
apt-get -y install strace ltrace && \
#
# perf (python3 also included)
apt-get -y install linux-tools-generic && ln -sf /usr/lib/linux-tools-*/* /usr/bin/ && \
#
apt-get -y install python3-pip python3-venv && \
#
# objdump ...
apt-get -y install binutils && \
#
# some file utilities
apt-get -y install attr && \
#
# some tools such as perf-tools need gawk ...
apt-get -y install gawk && \
#
# need for `mount -t cifs //IP/C /MOUNT_DIR -o user=USER,pass=PASSWD,dom=DOMAIN`
apt-get -y install cifs-utils && \
#
# some low level tools for container
apt-get -y install runc && \
#
# TODO: install bcc tools
#
git clone https://github.com/brendangregg/perf-tools /perf-tools && \
#
# install docker cli and docker-compose, and link host's /var/run/docker.sock in
# todo apt-get -y install docker-ce ... directly
#
curl -L https://download.docker.com/linux/static/stable/x86_64/docker-18.03.1-ce.tgz \
 | tar xz docker/docker && mv docker/docker /usr/bin/docker && rm -fr docker && \
curl -L https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker > /etc/bash_completion.d/docker && \
curl -L https://github.com/docker/compose/releases/download/1.21.0/docker-compose-`uname -s`-`uname -m` > /usr/bin/docker-compose && chmod +x /usr/bin/docker-compose && \
curl -L https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose && \
#
# config vim: disable swapfile creation due to it can not handle dir such as /proc/1/root/xxx
(echo && echo "set noswapfile") >> ~/.vimrc && \
#
# add some utilities into /usr/local/bin/, such as linux/cap-of-proc linux/cap-decode, but common/* are optional
git clone https://github.com/jjqq2013/bash-scripts && \
(cd bash-scripts/linux && for f in *; do [ -e /usr/local/bin/"$f" ] || cp "$f" /usr/local/bin/; done) && \
(cd bash-scripts/common && for f in *; do [ -e /usr/local/bin/"$f" ] || cp "$f" /usr/local/bin/; done) && \
rm -fr bash-scripts && \
#
# other optional utilities
wget https://github.com/sjitech/show-cmdline/releases/download/1.2/cmdline -O /usr/local/bin/cmdline && chmod +x /usr/local/bin/cmdline && \
#
touch /.rootfs-of-docker-geek && \
echo OK

COPY --from=util-linux-part-dist /dist /

ENV IS_DOCKER_GEEK=1

ENV PATH=$PATH:/perf-tools/bin
