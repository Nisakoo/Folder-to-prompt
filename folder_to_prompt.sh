#!/bin/bash

# Задаём системные инструкции в коде
declare -A SYSTEM_INSTRUCTIONS
SYSTEM_INSTRUCTIONS["error"]="Анализируй проблему, предлагай варианты исправления и поясняй логику."
SYSTEM_INSTRUCTIONS["optimize"]="Ищи узкие места, предлагай улучшения и объясняй преимущества изменений."
SYSTEM_INSTRUCTIONS["default"]="Выполняй поставленные задачи согласно лучшим практикам."
SYSTEM_INSTRUCTIONS["empty"]=" "

# Функция для отображения справки
usage() {
  echo "Скрипт для преобразования папки и ее содержимого в промпт для LLM"
  echo "-s <системная инструкция> - доступны: error, optimize, default, empty"
  echo "-p <пользовательская инструкция>"
  echo "[-e исключение1,исключение2,...] - скрывает содержимое файлов или папок, но не скрывает их положение в иерархии. Указываейте здесь файлы типа .env"
  echo "[-h скрытые1,скрытые2,...] - скрывает файлы или папки из файловой структуры, но не скрывает их содержимое"
  exit 1
}

# Инициализация переменных
system_key=""
user_instruction=""
exclude_list=()   # Для исключения содержимого файлов
hide_list=()      # Для исключения файлов и папок из файловой структуры

# Обработка аргументов командной строки
while getopts "s:p:e:h:" opt; do
  case $opt in
    s)
      system_key="$OPTARG"
      ;;
    p)
      user_instruction="$OPTARG"
      ;;
    e)
      # Разбиваем список исключений для содержимого по запятой
      IFS=',' read -ra exclude_list <<< "$OPTARG"
      ;;
    h)
      # Разбиваем список исключений для файловой структуры по запятой
      IFS=',' read -ra hide_list <<< "$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

# Проверка обязательных аргументов
if [ -z "$system_key" ] || [ -z "$user_instruction" ]; then
  usage
fi

# Получаем системную инструкцию по ключу или используем инструкцию по умолчанию
system_inst="${SYSTEM_INSTRUCTIONS[$system_key]}"
if [ -z "$system_inst" ]; then
  echo "Предупреждение: системная инструкция '$system_key' не найдена. Используется инструкция по умолчанию."
  echo ""
  system_inst="${SYSTEM_INSTRUCTIONS["default"]}"
fi

# Вывод промпта для LLM
echo "$system_inst"
echo ""
echo "$user_instruction"
echo ""
echo "Файловая структура текущей папки:"

# Вывод файловой структуры с учётом исключений (-h)
if command -v tree &>/dev/null; then
  if [ ${#hide_list[@]} -gt 0 ]; then
    # Для tree требуется список через запятую
    hide_str=$(IFS=,; echo "${hide_list[*]}")
    tree -I "$hide_str"
  else
    tree .
  fi
else
  # fallback на find
  if [ ${#hide_list[@]} -gt 0 ]; then
    # Для grep -E создаём паттерн с объединением через |
    hide_pattern=$(IFS='|'; echo "${hide_list[*]}")
    find . -print | sed 's|^\./||' | grep -Ev "$hide_pattern"
  else
    find . -print | sed 's|^\./||'
  fi
fi

echo ""
echo "Содержимое файлов в текущей папке:"

# Обходим все файлы в текущей директории (включая поддиректории)
while IFS= read -r -d '' file; do
  exclude=false
  # Проверяем, содержит ли путь файла одну из строк из списка исключений (-e)
  for pattern in "${exclude_list[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      exclude=true
      break
    fi
  done
  if [ "$exclude" = false ]; then
    echo "----- Содержимое файла: ${file#./} -----"
    cat "$file"
    echo ""
  fi
done < <(find . -type f -print0)
