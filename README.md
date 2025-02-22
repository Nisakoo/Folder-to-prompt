# Folder-to-prompt
Скрипт для преобразования папки и ее содержимого в промпт для LLM

Файл `folder_to_prompt.sh` поместить в домашнюю дерикторию
Перед запуском сделать файл `folder_to_prompt.sh` исполняемым: `chmod 700 ~/folder_to_prompt.sh`

```
~/folder_to_prompt.sh -s review -e build,.clang-tidy,.clang-format,.github,.git,.vscode,.cache,a.out,README.md,.gitgnore > prompt.txt
```
