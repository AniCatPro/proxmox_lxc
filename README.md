# Создание LXC в Proxmox

Эта краткая инструкция по созданию LXC-контейнеров из этого репозитория в Proxmox. 

---

## Как использовать

### 1. Создай скрипт на Proxmox

Открой терминал Proxmox или подключись по SSH и создай файл скрипта:
```bash
nano create-lxc-dockge.sh 
```
или склонируй файл из репозитория со скриптом
```bash
git clone https://github.com/AniCatPro/proxmox_lxc.git
cd proxmox_lxc
```

### 2. Вставь туда скрипт из репозитория и сохрани

### 3. Сделай скрипт исполняемым
```bash
chmod +x create-lxc-dockge.sh
```

### 4. Запусти скрипт
```bash
chmod +x create-lxc-dockge.sh
```

> [!TIP]
> Посмотреть IP контейнера
> ```bash
> pct exec <CTID> ip a
> ```
