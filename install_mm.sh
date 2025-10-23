#!/bin/bash

set -e

echo "=== Установка MikroTik Manager (mm) ==="

# Определяем домашнюю директорию пользователя
if [ "$EUID" -eq 0 ]; then
    HOME_DIR="/root"
else
    HOME_DIR="$HOME"
fi

# Определяем директорию скриптов
if [ $# -eq 0 ]; then
    # Если путь не указан, используем текущую директорию
    if [[ -f "mikrotik_manager.sh" ]]; then
        SCRIPTS_DIR="$(pwd)"
    else
        echo "Ошиб: Не найден mikrotik_manager.sh в текущей директории"
        echo "Укажите путь к директории со скриптами:"
        echo "  ./install_mm.sh /полный/путь/к/директории"
        exit 1
    fi
else
    SCRIPTS_DIR="$1"
    if [[ ! -f "$SCRIPTS_DIR/mikrotik_manager.sh" ]]; then
        echo "Ошибка: Не найден mikrotik_manager.sh в указанной директории: $SCRIPTS_DIR"
        exit 1
    fi
fi

echo "Директория скриптов: $SCRIPTS_DIR"

# Создаем основной скрипт mm
cat > /usr/local/bin/mm << EOF
#!/bin/bash

SCRIPT_DIR="$SCRIPTS_DIR"
MAIN_SCRIPT="\$SCRIPT_DIR/mikrotik_manager.sh"

# Если скрипт не существует, выходим
if [[ ! -f "\$MAIN_SCRIPT" ]]; then
    echo "Ошибка: Основной скрипт не найден: \$MAIN_SCRIPT"
    exit 1
fi

# Функция для проверки доступности основного скрипта
check_main_script() {
    if [[ ! -x "\$MAIN_SCRIPT" ]]; then
        echo "Ошибка: Основной скрипт не исполняемый или не найден"
        exit 1
    fi
}

# Функция показа справки mm
show_help() {
    cat << EOM
MikroTik Manager (mm) - система управления роутерами MikroTik

Использование: mm <команда> [опции]

Основные команды:
  h, help                 Показать эту справку
  l, list                 Показать все роутеры и их статус
  lg, list-groups         Показать роутеры по группам
  
Команды развертывания:
  d, deploy [роутер]      Развернуть конфигурацию на роутер или все включенные
  da, deploy-all          Развернуть на все роутеры (включая выключенные)
  dg, deploy-group <гр>   Развернуть на все роутеры в группе

Управление роутерами:
  a, add <имя>            Добавить новый роутер
  e, edit <имя>           Редактировать конфигурацию роутера
  r, remove <имя>         Удалить роутер
  en, enable <роутер>     Включить роутер
  dis, disable <роутер>   Выключить роутер

Групповые операции:
  eng, enable-group <гр>  Включить все роутеры в группе
  disg, disable-group <гр> Выключить все роутеры в группе

Просмотр информации:
  sc, show-config <роут>  Показать конфигурацию роутера
  sr, show-results <роут> Показать последние результаты роутера

Сервисные команды:
  v, verify               Проверить сетевое соединение
  ev, edit-vars           Редактировать файл переменных
  b, backup               Создать резервную копию
  c, cleanup              Очистить старые файлы результатов
  s, status               Показать статус системы

Примеры:
  mm l                    # Список роутеров
  mm d                    # Развернуть на все включенные
  mm d router_rt1         # Развернуть на конкретный роутер
  mm dg core              # Развернуть на группу core
  mm e router_rt1         # Редактировать конфиг роутера
  mm eng branch           # Включить группу branch

Группы: core, branch, test

Для подробной справки по конкретной команде используйте: mm <команда> --help
EOM
}

# Обработка коротких команд
case "\$1" in
    "h"|"help")
        show_help
        ;;
    "l"|"list")
        check_main_script
        "\$MAIN_SCRIPT" list
        ;;
    "lg"|"list-groups")
        check_main_script
        "\$MAIN_SCRIPT" list-groups
        ;;
    "d"|"deploy")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" deploy "\$2"
        else
            "\$MAIN_SCRIPT" deploy
        fi
        ;;
    "da"|"deploy-all")
        check_main_script
        "\$MAIN_SCRIPT" deploy-all
        ;;
    "dg"|"deploy-group")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" deploy-group "\$2"
        else
            echo "Ошибка: Укажите группу"
            exit 1
        fi
        ;;
    "v"|"verify")
        check_main_script
        "\$MAIN_SCRIPT" verify
        ;;
    "a"|"add"|"add-router")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" add-router "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "e"|"edit"|"edit-router")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" edit-router "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "ev"|"edit-vars")
        check_main_script
        "\$MAIN_SCRIPT" edit-vars
        ;;
    "r"|"remove"|"remove-router")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" remove-router "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "en"|"enable")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" enable "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "dis"|"disable")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" disable "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "eng"|"enable-group")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" enable-group "\$2"
        else
            echo "Ошибка: Укажите группу"
            exit 1
        fi
        ;;
    "disg"|"disable-group")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" disable-group "\$2"
        else
            echo "Ошибка: Укажите группу"
            exit 1
        fi
        ;;
    "sc"|"show-config")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" show-config "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "sr"|"show-results")
        check_main_script
        if [[ -n "\$2" ]]; then
            "\$MAIN_SCRIPT" show-results "\$2"
        else
            echo "Ошибка: Укажите имя роутера"
            exit 1
        fi
        ;;
    "b"|"backup")
        check_main_script
        "\$MAIN_SCRIPT" backup
        ;;
    "c"|"cleanup")
        check_main_script
        "\$MAIN_SCRIPT" cleanup
        ;;
    "s"|"status")
        check_main_script
        "\$MAIN_SCRIPT" status
        ;;
    *)
        # Если команда не распознана, передаем все как есть в основной скрипт
        check_main_script
        "\$MAIN_SCRIPT" "\$@"
        ;;
esac
EOF

# Делаем mm исполняемым
chmod +x /usr/local/bin/mm

# Создаем скрипт автодополнения
COMPLETION_DIR="/etc/bash_completion.d"
if [ -d "$COMPLETION_DIR" ]; then
    cat > $COMPLETION_DIR/mm << 'EOF'
#!/bin/bash

_mm_completion() {
    local cur prev words cword
    _init_completion || return

    local commands="h help l list lg list-groups d deploy da deploy-all dg deploy-group v verify a add add-router e edit edit-router ev edit-vars r remove remove-router en enable dis disable eng enable-group disg disable-group sc show-config sr show-results b backup c cleanup s status"

    case $cword in
        1)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)
            case ${prev} in
                d|deploy|e|edit|edit-router|r|remove|remove-router|en|enable|dis|disable|sc|show-config|sr|show-results)
                    # Автодополнение для имен роутеров
                    local routers=$(find /root/mikrotik/scripts/configs -name "*.cfg" -exec basename {} .cfg \; 2>/dev/null)
                    COMPREPLY=($(compgen -W "$routers" -- "$cur"))
                    ;;
                dg|deploy-group|eng|enable-group|disg|disable-group)
                    # Автодополнение для групп
                    local groups="core branch test"
                    COMPREPLY=($(compgen -W "$groups" -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

complete -F _mm_completion mm
EOF
    chmod +x $COMPLETION_DIR/mm
    echo "Автодополнение установлено в $COMPLETION_DIR/mm"
else
    # Если нет системной директории, добавляем в .bashrc пользователя
    cat >> $HOME_DIR/.bashrc << 'EOF'

# Автодополнение для mm
_mm_completion() {
    local cur prev words cword
    _init_completion || return

    local commands="h help l list lg list-groups d deploy da deploy-all dg deploy-group v verify a add add-router e edit edit-router ev edit-vars r remove remove-router en enable dis disable eng enable-group disg disable-group sc show-config sr show-results b backup c cleanup s status"

    case $cword in
        1)
            COMPREPLY=($(compgen -W "$commands" -- "$cur"))
            ;;
        2)
            case ${prev} in
                d|deploy|e|edit|edit-router|r|remove|remove-router|en|enable|dis|disable|sc|show-config|sr|show-results)
                    local routers=$(find /root/mikrotik/scripts/configs -name "*.cfg" -exec basename {} .cfg \; 2>/dev/null)
                    COMPREPLY=($(compgen -W "$routers" -- "$cur"))
                    ;;
                dg|deploy-group|eng|enable-group|disg|disable-group)
                    local groups="core branch test"
                    COMPREPLY=($(compgen -W "$groups" -- "$cur"))
                    ;;
            esac
            ;;
    esac
}

complete -F _mm_completion mm
EOF
    echo "Автодополнение добавлено в $HOME_DIR/.bashrc"
fi

echo ""
echo "=== Установка завершена! ==="
echo ""
echo "MikroTik Manager (mm) успешно установлен."
echo ""
echo "Использование:"
echo "  mm help              - Показать справку"
echo "  mm list              - Список роутеров"
echo "  mm deploy            - Развернуть конфигурацию"
echo ""
echo "Автодополнение будет доступно после перезапуска терминала"
echo "или выполнения: source ~/.bashrc"
echo ""
echo "Директория скриптов: $SCRIPTS_DIR"
echo "Команда mm установлена в: /usr/local/bin/mm"