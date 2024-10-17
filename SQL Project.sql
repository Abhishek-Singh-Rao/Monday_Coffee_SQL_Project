-- Monday Coffee Data Analysis
-- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?

SELECT city_name, round((population*.25)/1000000,2) AS coffee_consumers_in_millions
FROM city
ORDER BY coffee_consumers_in_millions desc


-- Q.2 Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?

SELECT 
	city_name,
	SUM(total) as total_revenue
FROM city AS ci
LEFT JOIN customers AS cu
ON ci.city_id = cu.city_id
INNER JOIN sales as s
ON cu.customer_id = s.customer_id
WHERE EXTRACT(YEAR from sale_date) = 2023 and EXTRACT(QUARTER from sale_date) = 4
GROUP BY 1
ORDER BY 2 DESC

-- Q.3 Sales Count for Each Product
--How many units of each coffee product have been sold?
SELECT 
	product_name,
	count(total)
FROM products AS p
LEFT JOIN sales AS s
ON p.product_id = s.product_id
GROUP BY product_name
ORDER BY 2 DESC

-- Q.4 Average Sales Amount per City
-- What is the average sales amount per customer in each city?

SELECT
	ci.city_name,
	SUM(s.total) AS total_revenue,
	count(distinct s.customer_id) AS total_customers,
	ROUND(SUM(s.total)::numeric/count(distinct s.customer_id),2) as avg_rev_per_customer
FROM city AS ci
LEFT JOIN customers AS cu
ON ci.city_id = cu.city_id
INNER JOIN sales as s
ON cu.customer_id = s.customer_id
GROUP BY 1
ORDER BY 4 DESC


-- Q.5
-- City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%)
	
SELECT 
	city_name,
	round((population*.25)/1000000,2) as estimated_coffee_consumers,
	count(distinct s.customer_id) as total_current_cx
FROM city AS ci
LEFT JOIN customers AS cu
ON ci.city_id = cu.city_id
LEFT JOIN sales as s
ON cu.customer_id = s.customer_id
group By city_name, ci.population


-- -- Q6
-- Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?

SELECT *
FROM (
	SELECT
		ci.city_name,
		p.product_name,
		COUNT(s.sale_id),
		DENSE_RANK() OVER(PARTITION BY ci.city_name ORDER BY COUNT(s.sale_id) DESC) AS RANK
	FROM  sales as s
	JOIN products as p
	ON s.product_id = p.product_id
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1,2
) AS t1
WHERE rank <=3


-- Q.7
-- Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?

SELECT 
	ci.city_name,
	COUNT(DISTINCT c.customer_id) as unique_cx
FROM city as ci
LEFT JOIN
customers as c
ON c.city_id = ci.city_id
JOIN sales as s
ON s.customer_id = c.customer_id
WHERE 
	s.product_id BETWEEN 1 AND 14
GROUP BY 1

-- -- Q.8
-- Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer

SELECT
	ci.city_name,
	ci.estimated_rent,
	count(distinct s.customer_id) AS total_customers,
	ROUND(SUM(s.total)::numeric/count(distinct s.customer_id),2) as avg_rev_per_customer,
	ROUND(ci.estimated_rent::numeric/count(distinct s.customer_id),2) as avg_rent_per_customer
FROM city AS ci
JOIN customers AS cu
ON ci.city_id = cu.city_id
INNER JOIN sales as s
ON cu.customer_id = s.customer_id
GROUP BY 1,2
ORDER BY 4 DESC

-- Q.9
-- Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city
WITH
monthly_sales
AS
(
	SELECT 
		ci.city_name,
		EXTRACT(MONTH FROM sale_date) as month,
		EXTRACT(YEAR FROM sale_date) as YEAR,
		SUM(s.total) as total_sale
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1, 2, 3
	ORDER BY 1, 3, 2
),
growth_ratio
AS
(
		SELECT
			city_name,
			month,
			year,
			total_sale as cr_month_sale,
			LAG(total_sale, 1) OVER(PARTITION BY city_name ORDER BY year, month) as last_month_sale
		FROM monthly_sales
)

SELECT
	city_name,
	month,
	year,
	cr_month_sale,
	last_month_sale,
	ROUND(
		(cr_month_sale-last_month_sale)::numeric/last_month_sale::numeric * 100
		, 2
		) as growth_ratio

FROM growth_ratio
WHERE 
	last_month_sale IS NOT NULL	

-- Q.10
-- Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

WITH
city_table
AS
(
	SELECT 
		ci.city_name,
		SUM(s.total) as total_revenue,
		COUNT(DISTINCT s.customer_id) AS total_customers,
		ROUND(
			SUM(s.total)::numeric/COUNT(DISTINCT s.customer_id)::numeric,2) as avg_sale_pr_cx
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as ci
	ON ci.city_id = c.city_id
	GROUP BY 1
	ORDER BY 2
),
city_rent AS
(SELECT 
	city_name,
	estimated_rent,
	ROUND(population * 0.25 /1000000,2) AS estimated_coffee_consumer_in_millions
FROM city

)
SELECT 
	cr.city_name,
	total_revenue,
	cr.estimated_rent AS total_rent,
	ct.total_customers,
	estimated_coffee_consumer_in_millions,
	avg_sale_pr_cx,
	ROUND(estimated_rent :: numeric / 	ct.total_customers :: numeric,2) AS avg_rent_per_cx
FROM city_rent as cr
JOIN city_table as ct
ON cr.city_name = ct.city_name
ORDER BY 2 DESC
/*
Recomendation:

City 1: Pune
	1.Average rent per customer is very low.
	2.Highest total revenue.
	3.Average sales per customer is also high.

City 2: Delhi
	1.Highest estimated coffee consumers at 7.7 million.
	2.Highest total number of customers, which is 68.
	3.Average rent per customer is 330 (still under 500).

City 3: Jaipur
	1.Highest number of customers, which is 69.
	2.Average rent per customer is very low at 156.
	3.Average sales per customer is better at 11.6k.
\*
