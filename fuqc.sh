#!/bin/bash
set -e

### CONFIG ###
CTID=120
HOSTNAME=yiff-gallery
STORAGE=GB
BRIDGE=vmbr0
DISK_SIZE=20
MEMORY=2048
CORES=2
PASSWORD_TEMP="changeme"

TEMPLATE="local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"

echo "=== Création du LXC $CTID ==="

pct create $CTID $TEMPLATE \
  --hostname $HOSTNAME \
  --storage $STORAGE \
  --rootfs ${STORAGE}:${DISK_SIZE} \
  --memory $MEMORY \
  --cores $CORES \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --password $PASSWORD_TEMP \
  --unprivileged 1 \
  --features nesting=1,keyctl=1

echo "=== Démarrage du LXC ==="
pct start $CTID

echo "=== Attente 10 secondes ==="
sleep 10

echo "=== Installation curl dans le LXC ==="
pct exec $CTID -- bash -c "apt update && apt install -y curl"

echo "=== Téléchargement script d'installation ==="
pct exec $CTID -- bash -c "curl -o /root/install-yiff.sh https://raw.githubusercontent.com/KioQc/prox/main/fuqc.sh || true"

echo
echo "LXC créé ✅"
echo "Entre dans le LXC avec : pct enter $CTID"
echo "Puis lance : bash /root/install-yiff.sh"
