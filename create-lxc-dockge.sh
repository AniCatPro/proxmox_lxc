# Copyright (c) 2025 anicatpro
# Author: anicatpro (Paul Afanasev)
# License: MIT

#!/usr/bin/env bash
set -e

CTID=100  		 # ID контейнера, ПОМЕНЯТЬ!
HOSTNAME="dockge"	 # Название контейнера
DISK=60   		 # GB, максимум по df -h /var/lib/vz
RAM=12288  		 # GB, min - 4096; mid - 8192; + 4GB ES
CPU=4     		 #core, min - 2; mid - 4; + 2core ES 
BRIDGE=vmbr0
ROOT_PW="pass123"
STORAGE=local

DOCKER_DATA_DIR=/root/dockge-data
TEMPLATE_NAME="debian-12-standard"

# storage local 
pvesm set local --content images,rootdir,iso,vztmpl,backup

echo "=== [1/7] Поиск свежего шаблон $TEMPLATE_NAME ==="
TEMPL_FULL=$(pveam available | grep "$TEMPLATE_NAME" | sort -V | tail -n 1 | awk '{print $2}')
if [ -z "$TEMPL_FULL" ]; then
  echo "Нет подходящего Debian 12 шаблона! Проверь pveam available вручную."
  exit 1
fi

echo "Используем шаблон: $TEMPL_FULL"
if ! ls /var/lib/vz/template/cache/$TEMPL_FULL 2>/dev/null; then
  echo "Скачиваем шаблон..."
  pveam download local "$TEMPL_FULL"
else
  echo "Шаблон уже скачан."
fi

echo "=== [2/7] Проверка места на storage $STORAGE ==="
if [ "$STORAGE" = "local" ]; then
  AVAIL=$(df -BG --output=avail /var/lib/vz | tail -1 | tr -dc '0-9')
  echo "Доступно на /var/lib/vz: $AVAIL GB"
  if (( DISK > AVAIL )); then
    echo "Недостаточно места! Уменьшаем rootfs DISK до ${AVAIL}ГБ..."
    DISK=$AVAIL
  fi
fi

echo "=== [3/7] Создаём контейнер LXC $CTID ==="
pct destroy $CTID --force 2>/dev/null || true

pct create $CTID local:vztmpl/"$TEMPL_FULL" \
  --hostname $HOSTNAME \
  --cores $CPU --memory $RAM --swap $RAM \
  --rootfs $STORAGE:${DISK} \
  --net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  --features nesting=1 \
  --unprivileged 1 \
  --password "$ROOT_PW" \
  --start 0

echo "=== [4/7] docker-friendly ==="
LXC_CONF="/etc/pve/lxc/${CTID}.conf"
cat <<EOFS >> $LXC_CONF
lxc.apparmor.profile: unconfined
lxc.cap.drop:
lxc.cgroup2.devices.allow: a
lxc.mount.auto: "proc:rw sys:rw"
lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file,optional
lxc.autodev: 1
lxc.proc.seccomp: unconfined
EOFS

echo "=== [5/7] Запускаем контейнер LXC ==="
pct start $CTID

echo "=== [6/7] Устанавливаем Docker и Dockge (может занять 2-5 минут) ==="
pct exec $CTID -- bash -c "
apt-get update
apt-get install -y curl sudo
curl -fsSL https://get.docker.com | bash
systemctl enable --now docker
docker run -d \
  --name dockge \
  -p 5001:5001 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $DOCKER_DATA_DIR:/app/data \
  --restart unless-stopped \
  louislam/dockge:latest
"

echo "=== [7/7] Готово!"
IP=$(pct exec $CTID -- hostname -I | awk '{print $1}')
echo "Dockge доступен: http://$IP:5001"
echo "Внутри LXC: root/$ROOT_PW"
echo "docker info (внутри):"
pct exec $CTID -- docker info | grep -E 'Server Version|Storage Driver|Cgroup Driver|Security Options|Operating System|Architecture|Kernel Version'

echo "=== Скрипт завершён ==="
