#!/bin/bash

# Задаём системные инструкции в коде
declare -A SYSTEM_INSTRUCTIONS
SYSTEM_INSTRUCTIONS["error"]="Анализируй проблему, предлагай варианты исправления и поясняй логику."
SYSTEM_INSTRUCTIONS["optimize"]="Ищи узкие места, предлагай улучшения и объясняй преимущества изменений."
SYSTEM_INSTRUCTIONS["default"]="Выполняй поставленные задачи согласно лучшим практикам."
SYSTEM_INSTRUCTIONS["review"]="Сделай отчет по следующему коду:"
SYSTEM_INSTRUCTIONS["empty"]=" "

# Функция для отображения справки
usage() {
  echo "Скрипт для преобразования папки и ее содержимого в промпт для LLM"
  echo "-s <системная инструкция> - доступны: error, optimize, default, empty (обязательный)"
  echo "[-p <пользовательская инструкция>] (необязательный)"
  echo "[-e исключение1,исключение2,...] - полностью исключает файлы или папки из файловой структуры и не показывает их содержимое"
  echo "[-h скрытые1,скрытые2,...] - скрывает содержимое файлов, но отображает файлы или папки в файловой структуре"
  exit 1
}

# Инициализация переменных
system_key=""
user_instruction=""
exclude_list=()   # Для полного исключения файлов/папок (и из структуры, и из содержимого)
hide_list=()      # Для скрытия содержимого файлов

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
      # Разбиваем список исключений для файлов/папок по запятой
      IFS=',' read -ra exclude_list <<< "$OPTARG"
      ;;
    h)
      # Разбиваем список для скрытия содержимого файлов по запятой
      IFS=',' read -ra hide_list <<< "$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

# Проверка обязательных аргументов
if [ -z "$system_key" ]; then
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
if [ -n "$user_instruction" ]; then
  echo "$user_instruction"
  echo ""
fi
echo "Файловая структура текущей папки:"

# Вывод файловой структуры с учетом исключений (-e)
if command -v tree &>/dev/null; then
  if [ ${#exclude_list[@]} -gt 0 ]; then
    # Для tree требуется список через запятую
    exclude_str=$(IFS=,; echo "${exclude_list[*]}")
    tree -I "$exclude_str"
  else
    tree .
  fi
else
  # fallback на find
  if [ ${#exclude_list[@]} -gt 0 ]; then
    # Для grep -E создаём паттерн с объединением через |
    exclude_pattern=$(IFS='|'; echo "${exclude_list[*]}")
    find . -print | sed 's|^\./||' | grep -Ev "$exclude_pattern"
  else
    find . -print | sed 's|^\./||'
  fi
fi

echo ""
echo "Содержимое файлов в текущей папке:"

# Обходим все файлы в текущей директории (включая поддиректории)
while IFS= read -r -d '' file; do
  # Если файл соответствует шаблонам из exclude_list (-e), пропускаем его полностью
  skip=false
  for pattern in "${exclude_list[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      skip=true
      break
    fi
  done
  if [ "$skip" = true ]; then
    continue
  fi

  echo "----- Содержимое файла: ${file#./} -----"
  # Если файл соответствует шаблонам из hide_list (-h), скрываем его содержимое
  hide=false
  for pattern in "${hide_list[@]}"; do
    if [[ "$file" == *"$pattern"* ]]; then
      hide=true
      break
    fi
  done
  if [ "$hide" = true ]; then
    echo "Содержимое скрыто"
  else
    cat "$file"
  fi
  echo ""
done < <(find . -type f -print0)
