#!/bin/bash

# Система управления роутерами MikroTik
# Автор: Сетевой администратор

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Без цвета

# Функции логирования
log_info() { echo -e "${BLUE}[ИНФО]${NC} $1"; }
log_success() { echo -e "${GREEN}[УСПЕХ]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ]${NC} $1"; }
log_error() { echo -e "${RED}[ОШИБКА]${NC} $1"; }
log_debug() { echo -e "${PURPLE}[ОТЛАДКА]${NC} $1"; }
log_action() { echo -e "${CYAN}[ДЕЙСТВИЕ]${NC} $1"; }

# Конфигурация
VARS_FILE="$BASE_DIR/vars/mikrotik_vars.yml"
CONFIG_DIR="$BASE_DIR/configs"
RESULTS_DIR="$BASE_DIR/results"
PLAYBOOKS_DIR="$BASE_DIR/playbooks"
BACKUP_DIR="$BASE_DIR/backups"

# Проверка зависимостей
check_dependencies() {
    local deps=("ansible" "sshpass" "python3")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Не найдена зависимость: $dep"
            exit 1
        fi
    done
    
    # Проверка Python YAML модуля
    if ! python3 -c "import yaml" &> /dev/null; then
        log_info "Установка Python YAML модуля..."
        pip3 install pyyaml
    fi
    
    # Проверка редактора nano
    if ! command -v nano &> /dev/null; then
        log_warning "Редактор nano не найден, будет использован vi"
    fi
    
    log_success "Все зависимости удовлетворены"
}

# Функции обработки YAML на Python
python_list_routers() {
    python3 -c "
import yaml
import sys

try:
    with open('$VARS_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
    
    routers_found = False
    for key, value in data.items():
        if key.startswith('router_'):
            routers_found = True
            enabled = '🟢 ВКЛЮЧЕН' if value.get('enabled') else '🔴 ВЫКЛЮЧЕН'
            desc = value.get('description', 'Нет описания')
            host = value.get('host', 'Нет хоста')
            group = value.get('group', 'unknown')
            print(f'{key:20} {desc:25} {host:15} {group:10} {enabled}')
    
    if not routers_found:
        print('Роутеры не найдены в конфигурации')
        
except FileNotFoundError:
    print('ОШИБКА: Файл переменных не найден: $VARS_FILE')
except Exception as e:
    print(f'ОШИБКА: {e}')
"
}

python_get_router_groups() {
    python3 -c "
import yaml
import sys

try:
    with open('$VARS_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
    
    groups = {}
    for key, value in data.items():
        if key.startswith('router_'):
            group = value.get('group', 'unknown')
            if group not in groups:
                groups[group] = []
            groups[group].append(key)
    
    for group, routers in groups.items():
        enabled_count = sum(1 for r in routers if data[r].get('enabled'))
        print(f'{group}: {len(routers)} роутеров ({enabled_count} включено)')
        for router in routers:
            status = '🟢' if data[router].get('enabled') else '🔴'
            print(f'  {status} {router}')
        
except Exception as e:
    print(f'ОШИБКА: {e}')
"
}

python_get_routers_by_group() {
    local group="$1"
    python3 -c "
import yaml
import sys

try:
    with open('$VARS_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
    
    routers = []
    for key, value in data.items():
        if key.startswith('router_') and value.get('group') == '$group':
            routers.append(key)
    
    print(' '.join(routers))
        
except Exception as e:
    print(f'ОШИБКА: {e}')
"
}

python_add_router() {
    local name="$1"
    local ip="$2"
    local desc="$3"
    local group="$4"
    local password="$5"
    
    python3 -c "
import yaml
import sys

try:
    # Чтение существующих данных
    try:
        with open('$VARS_FILE', 'r') as f:
            data = yaml.safe_load(f) or {}
    except FileNotFoundError:
        data = {'mikrotik_common': {'ssh_options': '-o HostKeyAlgorithms=+ssh-rsa -o KexAlgorithms=+diffie-hellman-group1-sha1'}}
    
    # Добавление нового роутера
    data['$name'] = {
        'host': '$ip',
        'user': 'admin',
        'password': '$password',
        'description': '$desc',
        'enabled': False,
        'group': '${group:-branch}',
        'config_file': '${name}_config.txt'
    }
    
    # Запись обратно
    with open('$VARS_FILE', 'w') as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    
    print('SUCCESS')
    
except Exception as e:
    print(f'ОШИБКА: {e}')
    sys.exit(1)
"
}

python_remove_router() {
    local name="$1"
    
    python3 -c "
import yaml
import sys

try:
    with open('$VARS_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
    
    if '$name' in data:
        del data['$name']
        with open('$VARS_FILE', 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
        print('SUCCESS')
    else:
        print('ОШИБКА: Роутер не найден')
        sys.exit(1)
        
except Exception as e:
    print(f'ОШИБКА: {e}')
    sys.exit(1)
"
}

python_toggle_router() {
    local name="$1"
    local status="$2"
    
    python3 -c "
import yaml
import sys

try:
    with open('$VARS_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
    
    if '$name' in data:
        data['$name']['enabled'] = $status
        with open('$VARS_FILE', 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
        print('SUCCESS')
    else:
        print('ОШИБКА: Роутер не найден')
        sys.exit(1)
        
except Exception as e:
    print(f'ОШИБКА: {e}')
    sys.exit(1)
"
}

python_enable_group() {
    local group="$1"
    local status="$2"
    
    python3 -c "
import yaml
import sys

try:
    with open('$VARS_FILE', 'r') as f:
        data = yaml.safe_load(f) or {}
    
    updated = 0
    for key, value in data.items():
        if key.startswith('router_') and value.get('group') == '$group':
            data[key]['enabled'] = $status
            updated += 1
    
    if updated > 0:
        with open('$VARS_FILE', 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
        print(f'SUCCESS:{updated}')
    else:
        print('ОШИБКА: Роутеры в группе не найдены')
        sys.exit(1)
        
except Exception as e:
    print(f'ОШИБКА: {e}')
    sys.exit(1)
"
}

# Показать справку
show_usage() {
    cat << EOF
Система управления роутерами MikroTik

Использование: $0 <команда> [опции]

Команды:
  list                   Показать все роутеры и их статус
  list-groups            Показать роутеры по группам
  deploy [роутер|группа] Развернуть конфигурацию на роутер, группу или все включенные
  deploy-all             Развернуть на все роутеры (включая выключенные)
  deploy-group <группа>  Развернуть на все роутеры в группе
  verify                 Проверить сетевое соединение
  add-router <имя>       Добавить новый роутер
  edit-router <имя>      Редактировать конфигурацию роутера через nano
  edit-vars              Редактировать файл переменных через nano
  remove-router <имя>    Удалить роутер
  enable <роутер>        Включить роутер
  disable <роутер>       Выключить роутер
  enable-group <группа>  Включить все роутеры в группе
  disable-group <группа> Выключить все роутеры в группе
  show-config <роутер>   Показать конфигурацию роутера
  show-results <роутер>  Показать последние результаты роутера
  backup                 Создать резервную копию конфигураций
  cleanup                Очистить старые файлы результатов
  status                 Показать статус системы

Примеры:
  $0 list
  $0 deploy                  # Все включенные роутеры
  $0 deploy router_rt1       # Конкретный роутер
  $0 deploy-group core       # Все роутеры в группе core
  $0 deploy-all              # Принудительно на все роутеры
  $0 edit-router router_rt1  # Редактировать конфиг роутера
  $0 enable-group branch     # Включить все роутеры branch
  $0 status                  # Статус системы

Группы: core, branch, test
EOF
}

# Показать все роутеры
list_routers() {
    log_info "Список всех роутеров:"
    echo "===================================================================="
    echo "Имя                 Описание           Хост           Группа      Статус"
    echo "===================================================================="
    python_list_routers
}

# Показать роутеры по группам
list_groups() {
    log_info "Роутеры по группам:"
    python_get_router_groups
}

# Развернуть конфигурацию
deploy_config() {
    local target="$1"
    
    if [ -z "$target" ]; then
        log_info "Развертывание конфигурации на все включенные роутеры..."
        cd "$PLAYBOOKS_DIR" && ansible-playbook "main.yml" -e "operation_mode=deploy"
    
    elif [[ "$target" == router_* ]]; then
        log_info "Развертывание конфигурации на $target..."
        cd "$PLAYBOOKS_DIR" && ansible-playbook "single_router.yml" -e "target_router=$target"
    
    else
        log_error "Неверная цель: $target. Используйте имя роутера или группу"
        show_usage
        exit 1
    fi
}

# Развернуть на все роутеры

deploy_all() {
    log_info "Развертывание конфигурации на все ВКЛЮЧЕННЫЕ роутеры..."
    cd "$PLAYBOOKS_DIR" && ansible-playbook "deploy_all_routers_simple.yml"
}
# Развернуть на группу
deploy_group() {
    local group="$1"
    
    if [ -z "$group" ]; then
        log_error "Имя группы обязательно"
        show_usage
        exit 1
    fi
    
    log_info "Развертывание конфигурации на все роутеры в группе: $group"
    routers=$(python_get_routers_by_group "$group")
    
    if [ -z "$routers" ]; then
        log_error "Роутеры в группе не найдены: $group"
        exit 1
    fi
    
    log_info "Роутеры в группе $group: $routers"
    
    for router in $routers; do
        log_info "Развертывание на $router..."
        cd "$PLAYBOOKS_DIR" && ansible-playbook "single_router.yml" -e "target_router=$router force_enable=true"
    done
}

# Проверить сеть
verify_network() {
    log_info "Проверка сетевого соединения..."
    cd "$PLAYBOOKS_DIR" && ansible-playbook "main.yml" -e "operation_mode=verify"
}

# Добавить новый роутер
add_router() {
    local router_name="$1"
    
    if [ -z "$router_name" ]; then
        log_error "Имя роутера обязательно"
        show_usage
        exit 1
    fi
    
    if [[ ! "$router_name" =~ ^router_ ]]; then
        log_warning "Имя роутера должно начинаться с 'router_'"
    fi
    
    log_info "Добавление нового роутера: $router_name"
    
    # Получить детали роутера
    read -p "Введите IP адрес роутера: " ip_address
    read -p "Введите описание роутера: " description
    read -p "Введите группу роутера [core/branch/test]: " group
    read -s -p "Введите пароль роутера: " password
    echo
    
    if [ -z "$ip_address" ] || [ -z "$description" ] || [ -z "$password" ]; then
        log_error "Все поля обязательны для заполнения"
        exit 1
    fi
    
    # Создать шаблон конфигурации
    local config_file="$CONFIG_DIR/${router_name}_config.txt"
    cat > "$config_file" << EOF
# Конфигурация для $router_name
# Описание: $description
# Группа: ${group:-branch}
# Создан: $(date)
# ===== КОМАНДЫ ПРОВЕРКИ =====
/interface print
/ip address print
/ip dhcp-server print
/ip route print
EOF
    
    log_success "Шаблон конфигурации создан: $config_file"
    
    # Добавить в файл переменных через Python
    log_info "Добавление роутера в файл переменных..."
    result=$(python_add_router "$router_name" "$ip_address" "$description" "$group" "$password")
    
    if [ "$result" = "SUCCESS" ]; then
        log_success "Роутер $router_name успешно добавлен"
        
        # ОБНОВЛЕНИЕ: Добавить роутер в deploy_all_routers_simple.yml
        log_info "Обновление playbook deploy_all_routers_simple.yml..."
        update_deploy_playbook "$router_name"
        
        log_info "Следующие шаги:"
        log_info "1. Просмотреть конфигурацию: $0 edit-router $router_name"
        log_info "2. Включить роутер: $0 enable $router_name"
        log_info "3. Развернуть конфигурацию: $0 deploy $router_name"
    else
        log_error "Ошибка добавления роутера: $result"
        exit 1
    fi
}

# Обновить playbook с новым роутером
update_deploy_playbook() {
    local router_name="$1"
    local playbook_file="$PLAYBOOKS_DIR/deploy_all_routers_simple.yml"
    
    log_info "Добавление $router_name в $playbook_file"
    
    # Создаем временный файл
    local temp_file=$(mktemp)
    
    # Используем Python для обновления YAML файла
    python3 -c "
import yaml
import sys

try:
    # Чтение существующего playbook
    with open('$playbook_file', 'r') as f:
        playbook = yaml.safe_load(f) or {}
    
    # Находим задачу 'Create list of enabled routers'
    tasks = playbook[0]['tasks']
    
    # Ищем индекс последней задачи добавления роутера
    last_router_index = 0
    for i, task in enumerate(tasks):
        if 'Add router_' in task.get('name', ''):
            last_router_index = i
    
    # Создаем новую задачу для добавления роутера
    new_task = {
        'name': f'Add $router_name if enabled',
        'set_fact': {
            'enabled_routers': '{{ enabled_routers + [\"$router_name\"] }}'
        },
        'when': f'mikrotik_vars.$router_name.enabled | default(false) | bool'
    }
    
    # Вставляем новую задачу после последней задачи добавления роутера
    tasks.insert(last_router_index + 1, new_task)
    
    # Записываем обратно
    with open('$playbook_file', 'w') as f:
        yaml.dump(playbook, f, default_flow_style=False, allow_unicode=True, indent=2, sort_keys=False)
    
    print('SUCCESS')
    
except Exception as e:
    print(f'ОШИБКА: {e}')
    sys.exit(1)
" > "$temp_file"
    
    local result=$(cat "$temp_file")
    rm "$temp_file"
    
    if [ "$result" = "SUCCESS" ]; then
        log_success "Playbook успешно обновлен"
    else
        log_warning "Не удалось обновить playbook: $result"
        log_info "Роутер добавлен в переменные, но нужно вручную добавить его в deploy_all_routers_simple.yml"
    fi
}

# Редактировать конфигурацию роутера
edit_router() {
    local router_name="$1"
    
    if [ -z "$router_name" ]; then
        log_error "Имя роутера обязательно"
        show_usage
        exit 1
    fi
    
    local config_file="$CONFIG_DIR/${router_name}_config.txt"
    
    if [ ! -f "$config_file" ]; then
        log_error "Файл конфигурации не найден: $config_file"
        log_info "Создание нового файла конфигурации..."
        add_router "$router_name"
        return
    fi
    
    log_info "Редактирование конфигурации для $router_name..."
    
    # Использовать nano если доступен, иначе vi
    if command -v nano &> /dev/null; then
        nano "$config_file"
    else
        vi "$config_file"
    fi
    
    log_success "Конфигурация обновлена: $config_file"
}

# Редактировать файл переменных
edit_vars() {
    log_info "Редактирование файла переменных..."
    
    if command -v nano &> /dev/null; then
        nano "$VARS_FILE"
    else
        vi "$VARS_FILE"
    fi
    
    log_success "Файл переменных обновлен: $VARS_FILE"
}

# Удалить роутер
remove_router() {
    local router_name="$1"
    
    if [ -z "$router_name" ]; then
        log_error "Имя роутера обязательно"
        show_usage
        exit 1
    fi
    
    log_warning "Это действие удалит роутер $router_name из системы"
    read -p "Вы уверены? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        # Удалить файл конфигурации
        local config_file="$CONFIG_DIR/${router_name}_config.txt"
        if [ -f "$config_file" ]; then
            rm "$config_file"
            log_success "Файл конфигурации удален: $config_file"
        fi
        
        # Удалить из файла переменных
        log_info "Удаление роутера из файла переменных..."
        result=$(python_remove_router "$router_name")
        
        if [ "$result" = "SUCCESS" ]; then
            log_success "Роутер $router_name успешно удален из переменных"
            
            # ОБНОВЛЕНИЕ: Удалить роутер из deploy_all_routers_simple.yml
            log_info "Удаление роутера из playbook..."
            remove_from_deploy_playbook "$router_name"
        else
            log_error "Ошибка удаления роутера: $result"
        fi
    else
        log_info "Операция отменена"
    fi
}

# Удалить роутер из playbook
remove_from_deploy_playbook() {
    local router_name="$1"
    local playbook_file="$PLAYBOOKS_DIR/deploy_all_routers_simple.yml"
    
    log_info "Удаление $router_name из $playbook_file"
    
    # Создаем backup
    cp "$playbook_file" "$playbook_file.backup"
    
    # Удаляем задачу для этого роутера
    sed -i "/Add $router_name if enabled/,/when: mikrotik_vars.$router_name.enabled/d" "$playbook_file"
    
    if [ $? -eq 0 ]; then
        log_success "Роутер удален из playbook"
    else
        log_warning "Не удалось удалить роутер из playbook"
        # Восстанавливаем backup
        cp "$playbook_file.backup" "$playbook_file"
        log_info "Роутер удален из переменных, но нужно вручную удалить его из deploy_all_routers_simple.yml"
    fi
    
    # Удаляем backup
    rm -f "$playbook_file.backup"
}


# Включить роутер
enable_router() {
    local router_name="$1"
    toggle_router "$router_name" "True"
}

# Выключить роутер
disable_router() {
    local router_name="$1"
    toggle_router "$router_name" "False"
}

# Переключить статус роутера
toggle_router() {
    local router_name="$1"
    local status="$2"
    
    if [ -z "$router_name" ]; then
        log_error "Имя роутера обязательно"
        show_usage
        exit 1
    fi
    
    log_info "$( [ "$status" = "True" ] && echo "Включение" || echo "Выключение" ) роутера $router_name..."
    result=$(python_toggle_router "$router_name" "$status")
    
    if [ "$result" = "SUCCESS" ]; then
        log_success "Роутер $router_name $( [ "$status" = "True" ] && echo "включен" || echo "выключен" )"
    else
        log_error "Ошибка переключения роутера: $result"
        exit 1
    fi
}

# Включить группу роутеров
enable_group() {
    local group="$1"
    toggle_group "$group" "True"
}

# Выключить группу роутеров
disable_group() {
    local group="$1"
    toggle_group "$group" "False"
}

# Переключить группу роутеров
toggle_group() {
    local group="$1"
    local status="$2"
    
    if [ -z "$group" ]; then
        log_error "Имя группы обязательно"
        show_usage
        exit 1
    fi
    
    log_info "$( [ "$status" = "True" ] && echo "Включение" || echo "Выключение" ) всех роутеров в группе: $group..."
    result=$(python_enable_group "$group" "$status")
    
    if [[ "$result" == SUCCESS:* ]]; then
        count=$(echo "$result" | cut -d: -f2)
        log_success "$count роутеров в группе $group $( [ "$status" = "True" ] && echo "включены" || echo "выключены" )"
    else
        log_error "Ошибка переключения группы: $result"
        exit 1
    fi
}

# Показать конфигурацию роутера
show_config() {
    local router_name="$1"
    
    if [ -z "$router_name" ]; then
        log_error "Имя роутера обязательно"
        show_usage
        exit 1
    fi
    
    local config_file="$CONFIG_DIR/${router_name}_config.txt"
    if [ -f "$config_file" ]; then
        log_info "Конфигурация для $router_name:"
        echo "=========================================="
        cat "$config_file"
        echo "=========================================="
    else
        log_error "Файл конфигурации не найден: $config_file"
    fi
}

# Показать последние результаты
show_results() {
    local router_name="$1"
    
    if [ -z "$router_name" ]; then
        log_error "Имя роутера обязательно"
        show_usage
        exit 1
    fi
    
    local latest_result=$(ls -t "$RESULTS_DIR/mikrotik_results_${router_name}"*.txt 2>/dev/null | head -1)
    
    if [ -n "$latest_result" ]; then
        log_info "Последние результаты для $router_name:"
        echo "=========================================="
        cat "$latest_result"
        echo "=========================================="
    else
        log_error "Результаты для $router_name не найдены"
    fi
}

# Резервное копирование конфигураций
backup_configs() {
    local backup_dir="$BACKUP_DIR/backup_$(date +%Y%m%d_%H%M%S)"
    
    log_info "Создание резервной копии в $backup_dir"
    mkdir -p "$backup_dir"
    
    cp -r "$CONFIG_DIR" "$backup_dir/"
    cp "$VARS_FILE" "$backup_dir/"
    
    # Создать файл информации о резервной копии
    cat > "$backup_dir/backup_info.txt" << EOF
Резервная копия создана: $(date)
Роутеров: $(python_list_routers | wc -l)
Расположение: $backup_dir
EOF
    
    log_success "Резервная копия успешно создана"
    echo "Расположение резервной копии: $backup_dir"
}

# Очистка старых результатов
cleanup_results() {
    log_info "Очистка файлов результатов старше 7 дней..."
    find "$RESULTS_DIR" -name "mikrotik_results_*.txt" -mtime +7 -delete
    log_success "Очистка завершена"
}

# Показать статус системы
show_status() {
    log_info "Статус системы управления MikroTik"
    echo "=========================================="
    
    # Подсчет роутеров
    total_routers=$(python_list_routers | grep -c "router_")
    enabled_routers=$(python_list_routers | grep -c "🟢 ВКЛЮЧЕН")
    
    echo "Роутеров: $enabled_routers/$total_routers включено"
    echo "Каталог конфигураций: $CONFIG_DIR ($(ls "$CONFIG_DIR"/*.txt 2>/dev/null | wc -l) файлов)"
    echo "Каталог результатов: $RESULTS_DIR ($(ls "$RESULTS_DIR"/*.txt 2>/dev/null | wc -l) файлов)"
    echo "Каталог резервных копий: $BACKUP_DIR ($(ls "$BACKUP_DIR" 2>/dev/null | wc -l) копий)"
    echo ""
    
    # Показать последние результаты
    log_info "Последние развертывания:"
    ls -lt "$RESULTS_DIR"/mikrotik_results_*.txt 2>/dev/null | head -5 | awk '{print $6, $7, $8, $9}'
}

# Установка зависимостей
install_dependencies() {
    log_info "Установка системных зависимостей..."
    sudo apt update
    sudo apt install -y ansible sshpass python3-pip nano
    
    log_info "Установка Python зависимостей..."
    pip3 install pyyaml
    
    log_success "Все зависимости успешно установлены"
}

# Основная логика скрипта
main() {
    local command="$1"
    local argument="$2"
    
    case "$command" in
        "install-deps")
            install_dependencies
            ;;
        *)
            check_dependencies
            ;;
    esac
    
    case "$command" in
        "list")
            list_routers
            ;;
        "list-groups")
            list_groups
            ;;
        "deploy")
            deploy_config "$argument"
            ;;
        "deploy-all")
            deploy_all
            ;;
        "deploy-group")
            deploy_group "$argument"
            ;;
        "verify")
            verify_network
            ;;
        "add-router")
            add_router "$argument"
            ;;
        "edit-router")
            edit_router "$argument"
            ;;
        "edit-vars")
            edit_vars
            ;;
        "remove-router")
            remove_router "$argument"
            ;;
        "enable")
            enable_router "$argument"
            ;;
        "disable")
            disable_router "$argument"
            ;;
        "enable-group")
            enable_group "$argument"
            ;;
        "disable-group")
            disable_group "$argument"
            ;;
        "show-config")
            show_config "$argument"
            ;;
        "show-results")
            show_results "$argument"
            ;;
        "backup")
            backup_configs
            ;;
        "cleanup")
            cleanup_results
            ;;
        "status")
            show_status
            ;;
        "install-deps")
            # Уже обработано выше
            ;;
        ""|"help")
            show_usage
            ;;
        *)
            log_error "Неизвестная команда: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Запуск основной функции со всеми аргументами
main "$@"
