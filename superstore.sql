

---Write an SQL query to solve the given problem statement.
---What percentage of total orders were shipped on the same date?

SELECT 
ROUND((COUNT(CASE WHEN order_date = ship_date THEN 1 END) / COUNT(*) * 100), 1) AS percentage_shipped_same_day
FROM superstore;

--- Name top 3 customers with highest total value of orders.
select top 3 Customer_Name,sum(sales) as total_sales from superstore
group by Customer_Name
order by sum(sales) desc

---Find the top 5 items with the highest average sales per day.

select top 5 Product_ID,sum(sales)/count(distinct Order_Date) as avg_sales_per_day from superstore
group by Product_ID
order by avg_sales_per_day desc

----Write a query to find the average order value for each customer, and rank the customers by their average order value.

select Customer_Name,avg(sales) as average_order_value,
RANk() over(order by avg(sales) desc) as sales_rank
from superstore
group by Customer_Name
order by average_order_value desc

---Give the name of customers who ordered highest and lowest orders from each city.

SELECT City,
       MAX(Sales) AS Highest_Order,
       MIN(Sales) AS Lowest_Order,
       FIRST_VALUE(Customer_Name) OVER (PARTITION BY City ORDER BY Sales DESC) AS Customer_Highest,
       FIRST_VALUE(Customer_Name) OVER (PARTITION BY City ORDER BY Sales ASC) AS Customer_Lowest
FROM superstore
GROUP BY City,sales,Customer_Name;


[Row_ID][Order_ID][Order_Date][Ship_Date][Ship_Mode][Customer_ID][Customer_Name][Segment]
[Country][City][State][Postal_Code][Region][Product_ID][Category][Sub_Category][Product_Name][Sales]

---What is the most demanded sub-category in the west region?

select top 1 Sub_Category,sum(sales) as total_sales  from superstore
where Region='west'
group by Sub_Category
order by total_sales desc

---Which order has the highest number of items? 

select top 1 Order_ID,count(*) as num_of_items from superstore
group by Order_ID
order by num_of_items desc

--- which order has the highest cumulative value?

select top 1 Order_ID,sum(sales) as total_value from superstore
group by Order_ID
order by total_value desc

---Which segment’s order is more likely to be shipped via first class?

SELECT 
    Segment, 
    COUNT(*) AS First_Class_Count,
    COUNT(*) * 100.0 / (SELECT COUNT(*) FROM superstore WHERE Ship_Mode = 'First Class') AS First_Class_Percentage
FROM superstore 
WHERE Ship_Mode = 'First Class'
GROUP BY Segment 
ORDER BY First_Class_Percentage DESC;

---Which city is least contributing to total revenue?

select top 1 city,sum(sales) as total_revenue from superstore
group by City
order by total_revenue asc

select * from superstore
---What is the average time for orders to get shipped after order is placed?

SELECT avg(DATEDIFF(day, Order_Date, Ship_Date)) AS Avg_Shipping_Time from superstore

---Which segment places the highest number of orders from each state and 
---which segment places the largest individual orders from each state?
SELECT 
    State, 
    MAX(Highest_Number_of_Orders_Segment) AS Segment_with_Highest_Number_of_Orders,
    MAX(Highest_Order_Value_Segment) AS Segment_with_Highest_Order_Value
FROM (
    SELECT 
        State, 
        Segment AS Highest_Number_of_Orders_Segment, 
        ROW_NUMBER() OVER (PARTITION BY State ORDER BY Order_Count DESC) AS Order_Count_Rank,
        Segment AS Highest_Order_Value_Segment,
        ROW_NUMBER() OVER (PARTITION BY State ORDER BY Order_Value DESC) AS Order_Value_Rank
    FROM (
        SELECT 
            State, 
            Segment, 
            COUNT(Order_ID) AS Order_Count,
            SUM(Sales) AS Order_Value
        FROM superstore
        GROUP BY State, Segment
    ) AS Segment_Orders
) AS Ranked_Segment_Orders
WHERE Order_Count_Rank = 1 AND Order_Value_Rank = 1
GROUP BY State;


---Find all the customers who individually ordered on 3 consecutive days where each day’s total order was more than 50 in value. **
WITH ordered_orders AS (
  SELECT Order_ID, Customer_ID, Order_Date, SUM(Sales) AS Total_Order_Value
  FROM superstore
  GROUP BY Order_ID, Customer_ID, Order_Date
  HAVING SUM(Sales) > 50
),
grouped_orders AS (
  SELECT Customer_ID, Order_Date,
         LAG(Order_Date, 1) OVER (PARTITION BY Customer_ID ORDER BY Order_Date) AS prev_order_date,
         LAG(Order_Date, 2) OVER (PARTITION BY Customer_ID ORDER BY Order_Date) AS prev_prev_order_date,
         SUM(Total_Order_Value) AS Total_Order_Value
  FROM ordered_orders
  GROUP BY Customer_ID, Order_Date
),
consecutive_orders AS (
  SELECT Customer_ID, Order_Date
  FROM grouped_orders
  WHERE DATEDIFF(day, prev_order_date, Order_Date) = 1
    AND DATEDIFF(day, prev_prev_order_date, prev_order_date) = 1
    AND Total_Order_Value > 50
),
eligible_customers AS (
  SELECT DISTINCT Customer_ID
  FROM consecutive_orders
)
SELECT *
FROM superstore
WHERE Customer_ID IN (SELECT Customer_ID FROM eligible_customers)
ORDER BY Customer_ID, Order_Date;


---Find the maximum number of days for which total sales on each day kept rising.**
WITH sales_total AS (
  SELECT Order_Date, SUM(Sales) AS total_sales
  FROM superstore
  GROUP BY Order_Date
), 
sales_diff AS (
  SELECT s1.Order_Date, s2.Order_Date AS next_date, s2.total_sales - s1.total_sales AS diff_sales
  FROM sales_total s1
  JOIN sales_total s2 ON s1.Order_Date = DATEADD(day, -1, s2.Order_Date)
),
sales_sequence AS (
  SELECT Order_Date, next_date, diff_sales, 1 AS sequence_length
  FROM sales_diff
  WHERE diff_sales > 0
  UNION ALL
  SELECT s.Order_Date, s.next_date, s.diff_sales, ss.sequence_length + 1 AS sequence_length
  FROM sales_diff s
  JOIN sales_sequence ss ON s.Order_Date = ss.next_date AND s.diff_sales > 0
)
SELECT MAX(sequence_length) AS max_sequence_length
FROM sales_sequence;
