/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Бакытжанова Наталья
 * Дата: 14.09.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT COUNT(id) AS id,
       SUM(payer) AS sum,
       AVG(payer)AS dolya
       FROM fantasy.users; 
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
--Находим количество платящих игроков каждой расы
WITH sum_race_pay AS (
SELECT COUNT(payer)AS users, --общее количество игроков
       SUM(payer) AS sum, -- количество платящих игроков
       AVG(payer),--доля платящих игроков
       race_id
FROM fantasy.users
GROUP BY race_id)--сократила запрос,по твоим рекомендациям,спасибо!
SELECT race,
       srp.sum,
       srp.users,
       srp.sum/srp.users::REAL AS dolya --доля платящих игроков среди всех зарегистрированных игроков каждой расы.
       FROM sum_race_pay AS srp
       JOIN fantasy.race AS r ON srp.race_id=r.race_id
       ORDER BY sum DESC;
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT COUNT(amount) AS cnt_amount,
       SUM(amount) AS sum_amount,
       MIN(amount) AS min_amount,
       ROUND(MAX(amount)) AS max_amount,
       ROUND(AVG(amount)) AS avg_amount,
       ROUND(PERCENTILE_DISC(0.50)WITHIN GROUP (ORDER BY amount)) AS mediana,
       ROUND(STDDEV (amount)) AS stddev
FROM fantasy.events; --округлила результаты
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT COUNT(amount), 
(COUNT(amount)::REAL / (SELECT COUNT(amount) FROM fantasy.events)) 
FROM fantasy.events 
WHERE amount = 0; --спасибо за рекомендации,код стал заметно короче и понятнее!
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
WITH zero_sale AS (-- Фильтрация покупок с ненулевой стоимостью и с пропусками в названии предмета
    SELECT 
        e.id AS player_id,
        e.item_code,
        e.amount
    FROM fantasy.events AS e
    LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
    WHERE e.amount != 0
      AND (i.game_items IS NOT NULL AND i.game_items != '')  -- Исключаем покупки предметов с пустыми или отсутствующими названиями
),
total_sale AS (
    -- Общее количество всех покупок и уникальных игроков
    SELECT 
        COUNT(z.amount) AS total_sales_amount,--исправила SUM на COUNT
        (SELECT COUNT(DISTINCT id) FROM fantasy.events) AS total_players --изменила эту строчку
    FROM zero_sale AS z
),
count_sale AS (
    -- Общее количество продаж и уникальных игроков для каждого предмета
    SELECT 
        z.item_code,
        COUNT(z.amount) AS item_sales_amount,--исправила SUM на COUNT 
        COUNT(DISTINCT z.player_id) AS count_player --добавила DISTINCT
    FROM zero_sale AS z
    GROUP BY z.item_code
),
items_1 AS (
    SELECT i.game_items,
        i.item_code
    FROM FANTASY.items AS  i
)
SELECT 
    i1.item_code,
    i1.game_items,
    cs.item_sales_amount AS total_sales,  -- Общее количество продаж предмета
    cs.item_sales_amount / ts.total_sales_amount::real AS relative_sales,  -- Относительная доля продаж
    ROUND(cs.count_player / ts.total_players::NUMERIC,2) AS buyer_percentage  -- Доля игроков, которые покупали предмет,округлила результат
FROM count_sale AS cs
JOIN items_1 AS i1 ON i1.item_code = cs.item_code
JOIN total_sale AS ts ON 1=1  
ORDER BY total_sales DESC;
-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH alies_1 AS(
SELECT race_id,
       COUNT(amount) AS cnt, --общее количество покупок
       SUM(amount) AS sale--внутриигровые покупки
FROM fantasy.users AS u
JOIN fantasy.events AS e ON u.id=e.id
GROUP BY race_id),
alies_2 AS (
SELECT race_id,
       COUNT(DISTINCT e.id) AS buyer_players --игроки с внутриигровой валютой
FROM fantasy.users AS u
JOIN fantasy.events AS e ON u.id=e.id
WHERE amount != 0
GROUP BY race_id),
alies_3 AS( --добавила подзапрос для нахождения платящих игроков
SELECT r.race_id,
       COUNT(DISTINCT u.id) AS plata
FROM fantasy.users AS u
JOIN fantasy.race AS r ON u.race_id=r.race_id
JOIN fantasy.events AS e ON u.id=e.id
WHERE payer=1 AND amount !=0
GROUP BY r.race_id),
alies_4 AS (
SELECT race_id,
       count(payer) AS total_players
FROM fantasy.users 
GROUP BY race_id),
doly AS(
SELECT a1.race_id,
       sale/cnt::REAL AS avg_sale,--средняя сумма одной покупки
       buyer_players/total_players ::REAL AS dolya_1,--не округлила потому что все по нулям
       plata/buyer_players::REAL AS dolya_2
       FROM alies_1 AS a1
       JOIN alies_2 AS a2 ON a1.race_id=a2.race_id
       JOIN alies_3 AS a3 ON a2.race_id=a3.race_id
       JOIN alies_4 AS a4 ON a3.race_id=a4.race_id)
SELECT race,
       total_players,
       buyer_players,
       dolya_1,
       dolya_2,
       round(cnt/buyer_players::REAL) AS avg_cnt,--среднее количество покупок на игрока
       avg_sale,
       round(sale/buyer_players::REAL) AS sum_sale --средняя суммарная стоимость всех покупок на игрока
       FROM alies_1 AS a1
       JOIN alies_2 AS a2 ON a1.race_id=a2.race_id
       JOIN alies_4 AS a4 ON a2.race_id=a4.race_id
       JOIN doly AS d ON d.race_id=a2.race_id
       JOIN fantasy.race AS r ON d.race_id=r.race_id
       ORDER BY sum_sale DESC