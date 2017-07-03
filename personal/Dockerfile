FROM osexp2000/ubuntu-with-utils

RUN \
#
# install docker cli and docker-compose, and link host's /var/run/docker.sock in
#
curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-17.06.0-ce.tgz > docker.tgz && \
tar xf docker.tgz -C /tmp docker/docker && mv /tmp/docker/docker /bin/docker_ && rm -fr docker.tgz /tmp/docker/ && \
curl -fsSL https://github.com/docker/compose/releases/download/1.14.0/docker-compose-`uname -s`-`uname -m` > /bin/docker-compose_ && chmod +x /bin/docker-compose_ && \
curl -fsSL https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker > /etc/bash_completion.d/docker && \
curl -fsSL https://raw.githubusercontent.com/docker/compose/master/contrib/completion/bash/docker-compose > /etc/bash_completion.d/docker-compose && \
(echo '#!/bin/bash' && \
 echo 'f=/proc/1/root/usr/bin/docker && [[ -x $f ]] && exec $f "$@" || /bin/docker_ "$@"' \
) > /bin/docker && \
chmod a+x /bin/docker && \
(echo '#!/bin/bash' && \
 echo 'f=/proc/1/root/usr/local/bin/docker-compose && [[ -x $f ]] && exec $f "$@" || /bin/docker-compose_ "$@"' \
) > /bin/docker-compose && \
chmod a+x /bin/docker-compose && \
ln -s /proc/1/root/run/docker.sock /var/run/docker.sock && \
ln -s /proc/1/root/var/lib/docker /var/lib/docker && \
#
# config vim: disable swapfile creation due to it can not handle dir such as /proc/1/root/xxx
#
(echo && echo "set noswapfile") >> ~/.vimrc && \
#
echo OK
