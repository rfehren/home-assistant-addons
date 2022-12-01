#!/usr/bin/with-contenv bashio
set -e

keydir=/data/ssh_keys
ssh_key=$keydir/id_ed25519

remuser=$(bashio::config 'username')
remhost=$(bashio::config 'hostname')
rem_ssh_port=$(bashio::config 'ssh_port')
tunnel_args=$(bashio::config 'remote_forwarding')
force_keygen=$(bashio::config 'force_keygen')

if [ "$force_keygen" != "false" ]; then
  bashio::log.info "Deleting existing key pair due to set 'force_keygen'"
  bashio::log.warning "Do not forget to unset 'force_keygen' in your add-on configuration"
  rm -rf "$keydir"
fi

if [ ! -d "$keydir" ]; then
  bashio::log.info "No previous key pair found"
  mkdir -p "$keydir"
  ssh-keygen -b 4096 -t ed25519 -N "" -C "hassio-ssh-tunnel" -f $ssh_key
  bashio::log.info "The public key is:"
  cat ${ssh_key}.pub
  bashio::log.warning "Add this key to '~/.ssh/authorized_keys' on your remote server now!"
  bashio::log.warning "Please restart add-on when done. Exiting..."
  exit 1
else
  bashio::log.info "Authentication key pair restored"
fi

bashio::log.info "The public key is:"
cat ${ssh_key}.pub
bashio::log.info "Add to '~/.ssh/authorized_keys' on your remote server"

if [ -z "$remhost" ]; then
  bashio::log.error "Please set 'hostname' in your config to the address of your remote server"
  exit 1
fi

test_command="/usr/bin/ssh "\
"-o BatchMode=yes "\
"-o ConnectTimeout=5 "\
"-o PubkeyAuthentication=no "\
"-o PasswordAuthentication=no "\
"-o KbdInteractiveAuthentication=no "\
"-o ChallengeResponseAuthentication=no "\
"-o StrictHostKeyChecking=no "\
"-p ${rem_ssh_port} -t -t "\
"test@${remhost} "\
"2>&1 || true"

if eval "$test_command" | grep -q "Permission denied"; then
  bashio::log.info "Testing SSH connection... SSH service reachable on remote server"
else
  bashio::log.error "SSH service can't be reached on remote server"
  exit 1
fi

bashio::log.info "Remote server host keys:"
ssh-keyscan -p $rem_ssh_port $remhost || true

if [ ! -z "$tunnel_args" ]; then
  bashio::log.error "No remote_forwarding options configured. Exiting ..."
  exit 1
fi

t_args=""
for a in $tunnel_args; do
  t_args="-R $a $t_args"
done

bashio::log.info "Starting ssh tunnel loop with the following command:"
echo ssh -o \"ProtocolKeepAlives 300\" -o \"ExitOnForwardFailure yes\" \
  -i $ssh_key $t_args -N -p $rem_ssh_port ${remuser}@$remhost

while true; do
  ssh -o "ProtocolKeepAlives 300" -o "ExitOnForwardFailure yes" \
    -i $ssh_key $t_args -N -p $rem_ssh_port ${remuser}@$remhost
  pkill -f "ProtocolKeepAlives 300"
  sleep 90
EOF
