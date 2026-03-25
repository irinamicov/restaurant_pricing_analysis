USE restaurant_db;
-- -- -- -- -- -- -- -- -- --


-- Explore the menu table --
-- -- -- -- -- -- -- -- -- --

SELECT * FROM menu_items;

-- 1.1 How many items are on the menu?

SELECT COUNT(*) AS total_menu_items FROM menu_items;

-- 1.2 What are the least and most expensive items on the menu?

SELECT item_name, category, price
FROM menu_items
WHERE price = (SELECT MIN(price) FROM menu_items)
   OR price = (SELECT MAX(price) FROM menu_items)
ORDER BY price;

-- 1.3 Price Comparison Across Categories:

-- How many dishes are in each category? 
-- What is the average dish price within each category? 
-- What are the least and most expensive items per category?
-- Which cuisine on the menu has most price variability?

SELECT 
	category, 
    COUNT(menu_item_id) AS num_dishes, 
    ROUND(AVG(price), 2) AS average_price,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
	ROUND(STDDEV(price), 2) AS price_variability
FROM menu_items
GROUP BY category
ORDER BY average_price DESC;

-- 1.4 What are the least and most expensive Italian dishes on the menu?
	
WITH Italian_Menu AS (
    SELECT item_name, price, category,
           RANK() OVER (ORDER BY price ASC) AS min_rank,
           RANK() OVER (ORDER BY price DESC) AS max_rank
    FROM menu_items
    WHERE category = 'Italian'
)
SELECT category, item_name, price
FROM Italian_Menu
WHERE min_rank = 1 OR max_rank = 1;

-- 1.5 What are the most common price points?

SELECT price, COUNT(*) AS count
FROM menu_items
GROUP BY price
ORDER BY count DESC, price ASC;

-- 1.6 Price Distribution Analysis: How is the menu distributed across pricing tiers?

SELECT 
    CASE 
        WHEN price < 10 THEN 'Low-cost (<$10)'
        WHEN price BETWEEN 10 AND 15 THEN 'Mid-range ($10-$15)'
        ELSE 'Premium ($16+)'
    END AS price_tier,
    COUNT(*) AS item_count
FROM menu_items
GROUP BY price_tier
ORDER BY FIELD(price_tier, 'Low-cost (<$10)', 'Mid-range ($10-$15)', 'Premium ($16+)');

-- 1.7 Price Distribution per Cuisine: How are different cuisines distributed across pricing tiers?

SELECT 
    category,
    CASE 
        WHEN price < 10 THEN 'Low-cost (<$10)'
        WHEN price BETWEEN 10 AND 15 THEN 'Mid-range ($10-$15)'
        ELSE 'Premium ($16+)'
    END AS price_tier,
    COUNT(*) AS item_count
FROM menu_items
GROUP BY category, price_tier
ORDER BY 
    category,
    FIELD(price_tier, 'Low-cost (<$10)', 'Mid-range ($10-$15)', 'Premium ($16+)');

-- 1.8 Which menu items fall into each pricing tier?

SELECT 
    CASE 
        WHEN price < 10 THEN 'Low-cost (<$10)'
        WHEN price BETWEEN 10 AND 15 THEN 'Mid-range ($10-$15)'
        ELSE 'Premium ($16+)'
    END AS price_tier,
        item_name
FROM menu_items
ORDER BY FIELD(price_tier, 'Low-cost (<$10)', 'Mid-range ($10-$15)', 'Premium ($16+)');


-- Explore the orders table --
-- -- -- -- -- -- -- -- -- --

SELECT * FROM order_details;

-- 2.1 What is the date range of the table?

SELECT MIN(order_date) AS start_date, MAX(order_date) AS end_date
FROM order_details;

-- 2.2 How many unique orders were made, and how many items were ordered in total?

SELECT 
  COUNT(DISTINCT order_id) AS total_orders, 
  COUNT(*) AS total_items_ordered 
FROM order_details;

-- 2.3 Order Size Distribution: How many items do people usually order at once?

SELECT 
  items_in_order,
  COUNT(*) AS num_orders
FROM (
  SELECT 
    order_id, 
    COUNT(item_id) AS items_in_order 
  FROM order_details
  GROUP BY order_id
) AS order_couns
GROUP BY items_in_order
ORDER BY items_in_order;

-- 2.4 Identify Outliers: How many large orders had more than 10 items?

WITH large_orders AS (
  SELECT order_id
  FROM order_details
  GROUP BY order_id
  HAVING COUNT(item_id) > 10
)
SELECT COUNT(*) AS large_orders_count
FROM large_orders;

-- 2.5 What are the busiest and slowest order times (by hour)?

SELECT 
  HOUR(order_time) AS order_hour,
  COUNT(DISTINCT order_id) AS num_orders
FROM order_details
GROUP BY order_hour
ORDER BY order_hour;

-- 2.6 What is the average number of items per order by hour of the day?

WITH order_item_counts AS (
  SELECT 
    order_id,
    HOUR(MIN(order_time)) AS order_hour,
    COUNT(*) AS item_count
  FROM order_details
  GROUP BY order_id
)
SELECT 
  order_hour,
  ROUND(AVG(item_count), 2) AS avg_items_per_order
FROM order_item_counts
GROUP BY order_hour
ORDER BY order_hour;

-- 2.7 What are the busiest and slowest days of the week?

SELECT 
  DAYNAME(order_date) AS day_of_week,
  COUNT(DISTINCT order_id) AS num_orders
FROM order_details
GROUP BY day_of_week
ORDER BY num_orders DESC;


-- Joined Analysis --
-- -- -- -- -- -- -- -- -- --

-- 3.1 How do pricing tiers perform in terms of items sold, total revenue, and average item price?

SELECT 
    CASE 
	  WHEN price < 10 THEN 'Low-cost (<$10)'
	  WHEN price BETWEEN 10 AND 15 THEN 'Mid-range ($10-$15)'
	  ELSE 'Premium ($16+)'
    END AS price_tier,
    COUNT(o.item_id) AS item_count,
	ROUND(AVG(price), 2) AS avg_price_per_item_sold,
    ROUND(SUM(price), 2) AS total_revenue
FROM menu_items AS m
INNER JOIN order_details AS o
	ON m.menu_item_id = o.item_id
GROUP BY price_tier
ORDER BY MIN(price);

-- 3.2 How many orders and items were placed per time segment? What were the total and average order values for each time segment?

WITH order_values AS (
  SELECT 
    o.order_id,
    MIN(o.order_time) AS order_time,
    COUNT(*) AS item_count,
    SUM(m.price) AS total_order_value
  FROM order_details o
  JOIN menu_items m ON o.item_id = m.menu_item_id
  GROUP BY o.order_id
),
bucketed_orders AS (
  SELECT 
    order_id,
    CASE 
      WHEN HOUR(order_time) BETWEEN 10 AND 11 THEN 'Brunch'
      WHEN HOUR(order_time) BETWEEN 12 AND 14 THEN 'Lunch'
      WHEN HOUR(order_time) BETWEEN 15 AND 17 THEN 'Afternoon'
      WHEN HOUR(order_time) BETWEEN 18 AND 20 THEN 'Dinner'
      ELSE 'Late Dinner'
    END AS time_bucket,
    item_count,
    total_order_value
  FROM order_values
)
SELECT 
  time_bucket,
  COUNT(*) AS num_orders,
  ROUND(AVG(item_count), 2) AS avg_items_per_order,
  ROUND(SUM(total_order_value), 2) AS total_revenue,
  ROUND(AVG(total_order_value), 2) AS avg_order_value
FROM bucketed_orders
GROUP BY time_bucket
ORDER BY FIELD(time_bucket, 'Brunch', 'Lunch', 'Afternoon', 'Dinner', 'Late Dinner');

-- 3.3 How many orders and items were placed per weekday? What were the total and average order values for each day?
  
  WITH order_values AS (
  SELECT 
    o.order_id,
    o.order_date,
    COUNT(o.item_id) AS item_count,
    SUM(m.price) AS total_order_value
  FROM order_details o
  JOIN menu_items m ON o.item_id = m.menu_item_id
  GROUP BY o.order_id, o.order_date
)
SELECT 
  DAYNAME(order_date) AS day_of_week,
  COUNT(*) AS num_orders,
  ROUND(AVG(item_count), 2) AS avg_items_per_order,
  ROUND(SUM(total_order_value), 2) AS total_revenue,
  ROUND(AVG(total_order_value), 2) AS avg_order_value
FROM order_values
GROUP BY day_of_week
ORDER BY 
  FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');
  
-- 3.4 Which cuisine categories are ordered the most? What is the average price per item sold and total revenue per cuisine?

SELECT 
	category, 
    ROUND(AVG(price), 2) AS avg_price_per_item_sold,
    COUNT(item_id) AS times_ordered,
    ROUND(SUM(price), 2) AS total_revenue
FROM menu_items AS m
INNER JOIN order_details AS o
	ON m.menu_item_id = o.item_id
GROUP BY category
ORDER BY times_ordered DESC;

-- 3.5 How do different pricing tiers perform across time segments in terms of items sold?

SELECT 
  CASE 
    WHEN m.price < 10 THEN 'Low-cost (<$10)'
    WHEN m.price BETWEEN 10 AND 15 THEN 'Mid-range ($10-$15)'
    ELSE 'Premium ($16+)' 
  END AS price_tier,
  CASE 
    WHEN HOUR(o.order_time) BETWEEN 10 AND 11 THEN 'Brunch'
    WHEN HOUR(o.order_time) BETWEEN 12 AND 14 THEN 'Lunch'
    WHEN HOUR(o.order_time) BETWEEN 15 AND 17 THEN 'Afternoon'
    WHEN HOUR(o.order_time) BETWEEN 18 AND 20 THEN 'Dinner'
    ELSE 'Late Dinner'
  END AS time_bucket,
  COUNT(*) AS items_sold
FROM order_details o
JOIN menu_items m ON o.item_id = m.menu_item_id
GROUP BY price_tier, time_bucket
ORDER BY 
  FIELD(time_bucket, 'Brunch', 'Lunch', 'Afternoon', 'Dinner', 'Late Dinner'),
  FIELD(price_tier, 'Low-cost (<$10)', 'Mid-range ($10-$15)', 'Premium ($16+)');

-- 3.6 How many items were sold by price tier and day of week?

SELECT 
  CASE 
    WHEN m.price < 10 THEN 'Low-cost (<$10)'
    WHEN m.price BETWEEN 10 AND 15 THEN 'Mid-range ($10-$15)'
    ELSE 'Premium ($16+)' 
  END AS price_tier,
  DAYNAME(o.order_date) AS day_of_week,
  COUNT(*) AS items_sold
FROM order_details o
JOIN menu_items m ON o.item_id = m.menu_item_id
GROUP BY price_tier, day_of_week
ORDER BY 
  FIELD(day_of_week, 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'),
  FIELD(price_tier, 'Low-cost (<$10)', 'Mid-range ($10-$15)', 'Premium ($16+)');
  
-- 3.7 What are the most and least ordered items, and what are their categories, prices & total revenue?

SELECT 
	item_name, 
	category, 
    price, 
COUNT(*) AS times_ordered,
ROUND(COUNT(*) * price, 2) AS total_revenue
FROM menu_items AS m
INNER JOIN order_details AS o
	ON m.menu_item_id = o.item_id
GROUP BY item_name, category, price
ORDER BY times_ordered DESC;