# MikroTik Network Management System

Система автоматизированного управления сетевыми устройствами MikroTik через Ansible.

## 📋 Содержание

- [Обзор системы](#обзор-системы)
- [Требования](#требования)
- [Установка](#установка)
- [Структура проекта](#структура-проекта)
- [Быстрый старт](#быстрый-старт)
- [Файлы конфигурации](#файлы-конфигурации)
- [Playbooks](#playbooks)
- [Скрипты управления](#скрипты-управления)
- [Примеры использования](#примеры-использования)
- [Резервное копирование](#резервное-копирование)
- [Устранение неисправностей](#устранение-неисправностей)

## 🚀 Обзор системы

Система предоставляет централизованное управление множеством роутеров MikroTik через единый интерфейс. Основные возможности:

- ✅ **Массовое развертывание** конфигураций на группы роутеров
- ✅ **Селективное выполнение** на включенных/выключенных устройствах
- ✅ **Автоматическое создание отчетов** о выполнении операций
- ✅ **Резервное копирование** конфигураций
- ✅ **Визуальный статус** всех устройств
- ✅ **Группировка роутеров** по функциональному назначению

## ⚙️ Требования

### Системные требования
- **ОС**: Linux/Ubuntu/Debian или WSL2 на Windows
- **Память**: 512 MB RAM
- **Диск**: 100 MB свободного места

### Программные зависимости
```bash
# Обязательные пакеты
ansible >= 2.9
sshpass
python3
python3-pip

# Python библиотеки
pyyaml
```

## 📥 Установка

### Автоматическая установка
```bash
sudo apt install git unzip -y
git clone https://github.com/1ZXXZ1/MT_N_M_S_A.git
cd MT_N_M_S_A/
unzip mikrotik.zip
cd mikrotik/scripts/
./mikrotik_manager.sh install-deps
```

### Ручная установка
```bash
sudo apt update
sudo apt install -y ansible sshpass python3 python3-pip nano
pip3 install pyyaml
```

## 📁 Структура проекта

```
mikrotik/
├── configs/                 # Конфигурационные файлы роутеров
│   ├── router_rt1_config.txt
│   ├── router_rt2_config.txt
│   └── ...
├── playbooks/              # Ansible плейбуки
│   ├── main.yml           # Основной плейбук
│   ├── deploy-all.yml     # Развертывание на все роутеры
│   ├── single_router.yml  # Работа с одним роутером
│   └── process_router.yml # Обработчик роутера
├── scripts/
│   └── mikrotik_manager.sh # Основной скрипт управления
├── vars/
│   └── mikrotik_vars.yml  # Переменные и настройки роутеров
├── templates/             # Шаблоны отчетов
│   ├── deployment_report.j2
│   └── output_template.j2
├── results/               # Результаты выполнения
└── backups/               # Резервные копии
```

## 🚀 Быстрый старт

### 1. Первоначальная настройка
```bash
cd mikrotik/scripts/
./mikrotik_manager.sh status
```

### 2. Просмотр доступных роутеров
```bash
./mikrotik_manager.sh list
```

### 3. Развертывание на все включенные роутеры
```bash
./mikrotik_manager.sh deploy
```

### 4. Проверка статуса
```bash
./mikrotik_manager.sh status
```

## 📄 Файлы конфигурации

### Конфигурационные файлы роутеров (`configs/`)
Файлы содержат команды RouterOS для выполнения на устройствах.

**Пример `router_rt1_config.txt`:**
```
# Конфигурация для router_rt1
# Описание: Главный роутер
# Группа: core
/interface print
/ip address print
/ip dhcp-server print
/ip route print
```

### Файл переменных (`vars/mikrotik_vars.yml`)
Содержит настройки всех роутеров и общие параметры.

**Структура конфигурации роутера:**
```yaml
router_rt1:
  host: 192.168.104.119
  user: admin
  password: '12345'
  description: Главный роутер
  enabled: true           # Включен для выполнения
  group: core            # Группа: core, branch, test
  config_file: router_rt1_config.txt
```

## 🎯 Playbooks

### Основные плейбуки:

| Файл | Назначение |
|------|------------|
| `main.yml` | Универсальный плейбук с выбором режима |
| `deploy-all.yml` | Принудительное развертывание на все роутеры |
| `single_router.yml` | Работа с одним конкретным роутером |
| `deploy_all_routers_simple.yml` | Развертывание на включенные роутеры |

### Режимы работы (`main.yml`):
- **deploy** - развертывание конфигурации
- **verify** - проверка соединения
- **cleanup** - очистка конфигурации

## 🛠 Скрипты управления

### Основной скрипт: `mikrotik_manager.sh`

#### Команды управления роутерами:
```bash
# Просмотр
./mikrotik_manager.sh list                    # Все роутеры
./mikrotik_manager.sh list-groups            # По группам

# Развертывание
./mikrotik_manager.sh deploy router_rt1      # На конкретный
./mikrotik_manager.sh deploy-all             # На все (принудительно)
./mikrotik_manager.sh deploy-group core      # На группу

# Управление конфигурацией
./mikrotik_manager.sh add-router router_new  # Добавить роутер
./mikrotik_manager.sh edit-router router_rt1 # Редактировать конфиг
./mikrotik_manager.sh edit-vars              # Редактировать переменные

# Управление статусом
./mikrotik_manager.sh enable router_rt1      # Включить роутер
./mikrotik_manager.sh disable router_rt2     # Выключить роутер
./mikrotik_manager.sh enable-group core      # Включить группу

# Сервисные команды
./mikrotik_manager.sh status                 # Статус системы
./mikrotik_manager.sh backup                 # Резервная копия
./mikrotik_manager.sh cleanup                # Очистка результатов
```

## 💡 Примеры использования

### Пример 1: Добавление нового роутера
```bash
./mikrotik_manager.sh add-router router_new

# Скрипт запросит:
# - IP адрес: 192.168.104.150
# - Описание: Новый филиал
# - Группу: branch
# - Пароль: ********
```

### Пример 2: Селективное развертывание
```bash
# Включить только core роутеры
./mikrotik_manager.sh enable-group core
./mikrotik_manager.sh disable-group branch

# Развернуть только на core
./mikrotik_manager.sh deploy
```

### Пример 3: Экстренное развертывание
```bash
# Развернуть на все роутеры независимо от статуса
./mikrotik_manager.sh deploy-all
```

### Пример 4: Работа с группой
```bash
# Показать роутеры в группе core
./mikrotik_manager.sh list-groups

# Развернуть на всю группу
./mikrotik_manager.sh deploy-group core

# Отключить всю группу
./mikrotik_manager.sh disable-group branch
```

## 💾 Резервное копирование

### Автоматическое резервное копирование
```bash
./mikrotik_manager.sh backup
```

Резервные копии сохраняются в `backups/backup_YYYYMMDD_HHMMSS/`

### Ручное резервное копирование
```bash
cp -r configs/ backups/manual_backup/
cp vars/mikrotik_vars.yml backups/manual_backup/
```

## 🔧 Устранение неисправностей

### Частые проблемы и решения

**Проблема**: Ошибка подключения по SSH
```bash
# Решение: Проверить доступность
ping 192.168.104.119
ssh admin@192.168.104.119
```

**Проблема**: Ошибка аутентификации
```bash
# Решение: Проверить пароль в mikrotik_vars.yml
./mikrotik_manager.sh edit-vars
```

**Проблема**: Роутер не выполняется
```bash
# Решение: Проверить статус
./mikrotik_manager.sh list
./mikrotik_manager.sh enable router_rt1
```

**Проблема**: Файл конфигурации не найден
```bash
# Решение: Создать конфиг
./mikrotik_manager.sh edit-router router_rt1
```

### Команды диагностики
```bash
# Проверить переменные
./mikrotik_manager.sh status

# Тестовое подключение
cd playbooks/
ansible-playbook debug/test_connectivity.yml

# Проверить загрузку переменных
ansible-playbook debug/test_vars_loading.yml
```

## 📊 Группы роутеров

Система поддерживает группировку роутеров:

- **core** - Основные маршрутизаторы
- **branch** - Роутеры филиалов  
- **test** - Тестовые устройства

## ⚠️ Важные замечания

1. **Безопасность**: Файл `mikrotik_vars.yml` содержит пароли в открытом виде
2. **Резервное копирование**: Всегда создавайте бэкапы перед масштабными изменениями
3. **Тестирование**: Сначала тестируйте на одном роутере, затем на группе
4. **Мониторинг**: Проверяйте результаты в папке `results/`

## 🆘 Получение помощи

```bash
# Показать справку
./mikrotik_manager.sh help
```


**Система управления MikroTik** · *Автоматизация сетевой инфраструктуры*
