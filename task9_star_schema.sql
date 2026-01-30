CREATE TABLE staging_orders (
    order_id INT,
    user_id INT,
    product_id INT,
    category VARCHAR(50),
    price NUMERIC(12,2),
    qty INT,
    total_price NUMERIC(12,2),
    order_date DATE,
    country VARCHAR(50),
    customer_segment VARCHAR(50)
);

SELECT * FROM staging_orders;

-- Dim Product
create table dim_product (
	product_key serial PRIMARY KEY,
	product_id int,
	category VARCHAR(50)
);

-- Dim customer
create table dim_customer (
	customer_key serial PRIMARY KEY,
	user_id INT,
	customer_segment VARCHAR(50)
);

-- Dim date
CREATE TABLE dim_date (
	date_key serial PRIMARY KEY,
	full_date date,
	year INT,
	month INT,
	day INT
);

-- Dim region
CREATE TABLE dim_geo (
	geo_key serial PRIMARY KEY,
	country VARCHAR(50)
);

-- Fact table
CREATE TABLE fct_sales (
	sales_key serial PRIMARY KEY,
	product_key INT,
	customer_key INT,
	date_key INT,
	geo_key INT,
	order_id INT,
	qty INT,
	total_price NUMERIC(12, 2),
	FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
	FOREIGN KEY (customer_key) REFERENCES dim_customer (customer_key),
	FOREIGN KEY (date_key) REFERENCES dim_date (date_key),
	FOREIGN KEY (geo_key) REFERENCES dim_geo (geo_key)
);

-- Insert values in dim_customer
INSERT INTO dim_customer (user_id, customer_segment)
SELECT DISTINCT user_id, min(customer_segment)
from staging_orders
GROUP BY user_id;
SELECT count(*) from dim_customer;
SELECT COUNT(DISTINCT user_id) FROM staging_orders;

-- Insert values in dim_product
INSERT INTO dim_product(product_id, category)
SELECT product_id, min(category) as category
FROM staging_orders
GROUP BY product_id;
select count(*) from dim_product;
SELECT COUNT(DISTINCT product_id) FROM staging_orders;

-- Insert values in dim_date
INSERT INTO dim_date (full_date, day, month, year)
SELECT distinct order_date,
	extract(day from order_date),
	extract(month from order_date),
	extract(year from order_date)
FROM staging_orders;
SELECT count(*) from dim_date;
SELECT count(distinct order_date) from staging_orders;

-- Insert values in dim_geo
INSERT INTO dim_geo (country)
SELECT distinct country
FROM staging_orders;
SELECT count(*) from dim_geo;
SELECT count(distinct country) from staging_orders;

-- Insert in fac_sales
INSERT INTO fct_sales (
	product_key,
	customer_key,
	date_key,
	geo_key,
	order_id,
	qty,
	total_price
)
SELECT p.product_key,
	   c.customer_key,
	   d.date_key,
	   g.geo_key,
	   s.order_id,
	   s.qty,
       s.total_price
FROM staging_orders s
JOIN dim_product p
	on p.product_id = s.product_id
JOIN dim_customer c
	on c.user_id = s.user_id
JOIN dim_date d
	on d.full_date = s.order_date
JOIN dim_geo g
	on g.country = s.country;

SELECT COUNT(*) FROM staging_orders;
SELECT COUNT(*) FROM fct_sales;

-- Index
CREATE INDEX join_product ON fct_sales(product_key);
CREATE INDEX join_customer ON fct_sales(customer_key);
CREATE INDEX join_date ON fct_sales(date_key);
CREATE INDEX join_geo ON fct_sales(geo_key);

-- Total Sales by Product Category
SELECT p.category, sum(s.total_price) as total_sales
FROM fct_sales s
join dim_product p
	on p.product_key = s.product_key
GROUP BY p.category
ORDER BY total_sales desc;

-- Total Sales by Country
SELECT g.country, sum(s.total_price) as total_sales
FROM fct_sales s
JOIN dim_geo g
	on g.geo_key = s.geo_key
GROUP BY g.country
ORDER BY total_sales DESC;

-- Monthly Sales Trend
SELECT d.year, d.month, sum(s.total_price) as total_sales
from fct_sales s
join dim_date d
	on d.date_key = s.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;

-- Customer segment
SELECT c.customer_segment, sum(s.total_price) as total_sales
from fct_sales s
join dim_customer c
	on c.customer_key = s.customer_key
GROUP BY c.customer_segment;

-- Top 10 Products
SELECT p.product_id, p.category, sum(s.total_price) as total_sales
from fct_sales s
join dim_product p
	on p.product_key = s.product_key
GROUP BY p.product_id, p.category
order by total_sales desc;