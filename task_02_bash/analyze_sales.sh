#!/bin/bash

# Реализуем нормальный режим прерывания работы скрипта при первой возникшей ошибки.
# В нашем случае никакая отказоустойчивость и т.п. - это может привести к неправильной работе скрипта.
set -e

# Проверяем, что скрипту передано достаточное количество аргументов.
if [ $# -eq 0 ]; then
  echo "Usage: ./analyze_sales.sh <file_path>"
  exit 1
fi

# Проверяем, что скрипту передан действительный путь до файла.
file_path="$1"
if [ ! -f "$file_path" ]; then
  echo "File not found: $file_path"
  exit 1
fi

# Инициализируем переменные - результат работы скрипта.
total_sales_sum=0
declare -A date_sales_sum
declare -A item_sales_stats

# Читаем каждую строку с данными из файла sales.txt.
while read -r line; do
  IFS=" " read -ra fields <<< "$line"
  
  if [ ${#fields[@]} -lt 5 ]
  then
    echo "Invalid data-string format: $line"
    exit 1
  fi

  date="${fields[0]}"
  day="${fields[1]}"
  item="${fields[2]}"
  price="${fields[3]}"
  amount="${fields[4]}"

  # Проверяем формат данных:
  # 0) дата должна действительно существовать;
  # 1) задан правильный день недели, он соответствует дате;
  # 2) количество должно быть числом от 1 и выше;
  # 3) цена должна быть равна 0 или строго больше 0;
  # 4) для цены также разрешается использование формата float.
  if ! date -d "$date" > /dev/null 2>&1; then
    echo "Invalid date format (must exists): $date"
    exit 1
  elif [[ ! "$(date -d "$date" +%A)" == "$day" ]]; then
    echo "Invalid day of week format: $day"
    exit 1
  elif [[ ! "$amount" =~ ^[1-9][0-9]*$ ]]; then
    echo "Invalid amount format (must be integer and > 0): $amount"
    exit 1
  elif [[ ! "$price" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "Invalid price format (must be > 0): $price"
    exit 1
  fi

  # Считаем сумму всех продаж + сумму продаж предмета за день.
  date_day_key="$date $day"
  item_day_sales_sum=$(bc <<< "$price * $amount")
  total_sales_sum=$(bc <<< "$total_sales_sum + $item_day_sales_sum")

  # Считаем сумму всех продаж по дням.
  # Сначала проверим, что ранее мы вообще учитывали дату - если нет, то инициализируем ее.
  if [ ! -v date_sales_sum["$date_day_key"] ]; then
    date_sales_sum["$date_day_key"]=0
  fi

  # Теперь учтем посчитанную ранее сумму продаж предмета за день для подсчета суммы продаж по дате.
  date_sales_sum["$date_day_key"]=$(bc <<< "${date_sales_sum["$date_day_key"]}+$item_day_sales_sum")

  # Считаем количество и сумму продаж конкретного товара.
  # Если ранее товар еще не был учтен, то инициализируем его статистику.
  if [ ! -v item_sales_stats["$item"] ]; then
    item_sales_stats["$item"]="0;0"
  fi

  # Учтем также посчитанную ранее сумму продаж предмета за день для подсчета его общей суммы продаж.
  IFS=";" read -r item_sum item_count <<< "${item_sales_stats["$item"]}"
  new_item_sum=$(bc <<< "$item_sum + $item_day_sales_sum")
  new_item_count=$(bc <<< "$item_count + $amount")
  item_sales_stats["$item"]="$new_item_sum;$new_item_count"
done < "$file_path"

if [[ "$total_sales_sum" == "0" ]]; then
  echo "File not contains sales!"
  exit 1
fi

# Теперь найдем день с максимальной выручкой.
day_with_max_sum_key=""
day_with_max_sum_value=0

for day_key in "${!date_sales_sum[@]}"; do
  day_value="${date_sales_sum[$day_key]}"

  if (( $(bc -l <<< "$day_value > $day_with_max_sum_value") )); then
    day_with_max_sum_key="$day_key"
    day_with_max_sum_value="$day_value"
  fi
done

# Также найдем самый популярный товар.
popular_item_key=""
popular_item_value=0
popular_item_stats=""

for item_key in "${!item_sales_stats[@]}"; do
  item_value="${item_sales_stats[$item_key]}"
  IFS=";" read -r item_sum item_count <<< "$item_value"

  if (( $(bc -l <<< "$item_count > $popular_item_value") )); then
    popular_item_key="$item_key"
    popular_item_value="$item_count"
    popular_item_stats="$item_value"
  fi
done

# Выведем результаты работы скрипта, наши переменные.
echo "Общая сумма продаж: $total_sales_sum"
echo "День с наибольшей выручкой: $day_with_max_sum_key (сумма продаж: $day_with_max_sum_value)"

# Также выведем и информацию о самом популярном предмете.
IFS=";" read -r popular_item_sum popular_item_count <<< "$popular_item_stats"
echo "Популярный товар: $popular_item_key (количество проданных единиц: $popular_item_count, сумма продаж: $popular_item_sum)"
