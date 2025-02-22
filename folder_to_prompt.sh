#!/bin/bash

# Задаём системные инструкции в коде
declare -A SYSTEM_INSTRUCTIONS
SYSTEM_INSTRUCTIONS["error"]="Анализируй проблему, предлагай варианты исправления и поясняй логику."
SYSTEM_INSTRUCTIONS["optimize"]="Ищи узкие места, предлагай улучшения и объясняй преимущества изменений."
SYSTEM_INSTRUCTIONS["default"]="Выполняй поставленные задачи согласно лучшим практикам."
SYSTEM_INSTRUCTIONS["review"]="Сделай отчет по следующему коду.
Отчет должен содержать описание используемых данных.
Тебе нужно указать все глобальные и статические переменные,
сигнатуры функций, объявление классов, структур и других конструкций языка C++.
Приведи только объявления, присваяемые значения писать не нужно.
После объявления обязательно приведи краткое описание.
СТРОГО ЗАПРЕЩАЕТСЯ УКАЗЫВАТЬ В ОТЧЕТЕ: локальные переменные, объявление namespace.
На этом отчет заканичивается, больше ничего писать не нужно

Пример отчета:

Объявления:
template <typename T> class Database;
> Шаблон класса Database для хранения и управления данными типа T.
template <typename T> Database<T>::Database(const char* filename);
> Конструктор класса Database, принимающий C-style строку filename.
template <typename T> Database<T>::Database(String filename);
> Конструктор класса Database, принимающий объект String filename.
template <typename T> Database<T>::~Database();
> Деструктор класса Database.
template <typename T> void Database<T>::Read();
> Метод класса Database для чтения данных из файла.
template <typename T> void Database<T>::Write();
> Метод класса Database для записи данных в файл.
template <typename T> void Database<T>::Sort();
> Метод класса Database для сортировки данных.
template <typename T> void Database<T>::Add(const T& element);
> Метод класса Database для добавления элемента типа T.
template <typename T> void Database<T>::Replace(std::size_t index, const T& element);
> Метод класса Database для замены элемента типа T по индексу.
template <typename T> void Database<T>::Remove(std::size_t index);
> Метод класса Database для удаления элемента по индексу.
template <typename T> void Database<T>::Edit(std::size_t index, const T& element);
> Метод класса Database для редактирования элемента типа T по индексу.
template <typename T> void Database<T>::Print(bool withIndexes = false);
> Метод класса Database для печати данных.
String filename;
> Приватная переменная filename класса Database для хранения имени файла.
Vector<T> array;
> Приватная переменная array класса Database для хранения массива элементов типа T.
enum class UserActions : int { kExit = 0, kReadFromFile = 1, kWriteToFile = 2, kSort = 3, kAdd = 4, kRemove = 5, kEdit = 6, kPrint = 7, };
> Перечисление UserActions для действий пользователя.
int main(int, char**);
> Главная функция программы, точка входа."

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
