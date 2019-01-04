#!/bin/sh

echo "Running setup script"

set -e

# Unset Kubernetes variables
unset $(env | awk -F= '/^\w/ {print $1}'|grep -e '_SERVICE_PORT$' -e '_TCP_ADDR$' -e '_TCP_PROTO$' |xargs)

BASEDIR=/opt/instruqt/bootstrap

# Create the required directories
mkdir -p /etc/dropbear ~/.ssh /var/log

GOTTY_SHELL=${INSTRUQT_GOTTY_SHELL:-/bin/sh}
GOTTY_PORT=${INSTRUQT_GOTTY_PORT:-15778}

# Create a clean .bash_history
rm -f ~/.bash_history && touch ~/.bash_history

# Set environment variables
export TERM=xterm-color
export PROMPT_COMMAND='history -a'

if [ -x "$(command -v systemctl)" ]; then
  sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config || true
  systemctl restart ssh* || true
elif [ -x "$(command -v service)" ]; then
  sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config || true
  service ssh restart || true
fi

# Fix for Alpine (MUSL <-> GLIBC)
if [ -f /etc/alpine-release ]; then
  cp $BASEDIR/files/sgerrand.rsa.pub /etc/apk/keys/sgerrand.rsa.pub
  apk add -q $BASEDIR/files/glibc-2.26-r0.apk
  rm -f ~/.ash_history && ln -s ~/.bash_history ~/.ash_history
fi

# TODO: remove this when the items below succeed
if [ -f /.ssh-keys/authorized_keys ]; then
  cat /.ssh-keys/authorized_keys >> ~/.ssh/authorized_keys
  /bin/chmod -Rf 0600 ~/.ssh
fi

# Copy the SSH keys from the secret
if [ -f /.authorized-keys/authorized_keys ]; then
  cat /.authorized-keys/authorized_keys >> ~/.ssh/authorized_keys
fi

# Copy the SSH keys from the secret
if [ -f /.ssh-keys/id_rsa ]; then
  cp /.ssh-keys/* ~/.ssh/
fi

# Set the correct permissions on the SSH directory
/bin/chmod -Rf 0600 ~/.ssh

# Prettify the terminal
cp ${BASEDIR}/config/vimrc $HOME/.vimrc
cp ${BASEDIR}/config/bashrc $HOME/.bashrc
cat ${BASEDIR}/config/profile >> /etc/profile

# Copy the helper functions
chmod +x ${BASEDIR}/bin/functions/*
cp -a ${BASEDIR}/bin/functions/* /bin/
cp -a ${BASEDIR}/bin/scp /bin/scp

# Start dropbear
pgrep sshd || ${BASEDIR}/bin/dumb-init ${BASEDIR}/bin/dropbear -s -g -F -R -E >/var/log/dropbear.log &

# Start the entrypoint of the user but only if it is different from the shell
if [ -n "$INSTRUQT_ENTRYPOINT" ] && [ "$INSTRUQT_ENTRYPOINT" != "$GOTTY_SHELL" ]; then
    ${BASEDIR}/bin/dumb-init -- /bin/sh -c "$INSTRUQT_ENTRYPOINT $INSTRUQT_CMD" >/var/log/process.log 2>&1 &
fi

# Start the CMD of the user but only if it is different from the shell
if [ -z "$INSTRUQT_ENTRYPOINT" ] && [ -n "$INSTRUQT_CMD" ] &&  [ "$INSTRUQT_CMD" != "$GOTTY_SHELL" ]; then
    ${BASEDIR}/bin/dumb-init -- /bin/sh -c "$INSTRUQT_CMD" >/var/log/process.log 2>&1 &
fi

echo "Setup completed, starting Gotty"

# Start Gotty
${BASEDIR}/bin/dumb-init --rewrite 2:15 --rewrite 15:9 ${BASEDIR}/bin/gotty \
        --title-format "Instruqt Shell" \
        --permit-write \
        --port "$GOTTY_PORT" \
        /bin/sh -c "$GOTTY_SHELL"

