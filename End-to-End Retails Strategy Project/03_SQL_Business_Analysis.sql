-- ============================================================
-- OLIST E-COMMERCE DATABASE — BUSINESS ANALYSIS QUERIES
-- ============================================================
-- Dataset: Olist Brazilian E-Commerce (2016–2018)
-- Database: olist_database
-- Table: olist (merged master table, 119,151 rows × 44 columns)
-- ============================================================

CREATE DATABASE IF NOT EXISTS olist_database;
USE olist_database;

SELECT COUNT(*) FROM olist;
SELECT * FROM olist;


-- ============================================================
-- PART 1: REVENUE & GROWTH
-- ============================================================

-- Q1: What is the total revenue generated (delivered orders only)?
SELECT 
    order_status,
    ROUND(SUM(COALESCE(payment_value,0)),2) AS total_revenue 
FROM olist
WHERE order_status = 'delivered'
GROUP BY order_status;


-- Q2: What is the monthly revenue trend over time (with MoM growth)?
WITH monthly AS (
    SELECT 
        DATE_FORMAT(order_purchase_timestamp,'%Y-%m') AS year_month,
        ROUND(SUM(COALESCE(payment_value,0)),2) AS revenue 
    FROM olist 
    WHERE order_status = 'delivered'
    GROUP BY DATE_FORMAT(order_purchase_timestamp,'%Y-%m')
)
SELECT 
    year_month,
    revenue,
    LAG(revenue) OVER(ORDER BY year_month) AS previous_month_revenue,
    ROUND(
        ((revenue - LAG(revenue) OVER(ORDER BY year_month)) /
         NULLIF(LAG(revenue) OVER(ORDER BY year_month), 0)) * 100
    ,2) AS mom_growth_pct
FROM monthly
ORDER BY year_month;


-- Q3: Which month had the highest and lowest sales?
WITH monthly_revenue AS (
    SELECT 
        YEAR(order_purchase_timestamp) AS year1,
        MONTH(order_purchase_timestamp) AS month1,
        ROUND(SUM(COALESCE(payment_value,0)),2) AS total_revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS highest_rank,
           DENSE_RANK() OVER (ORDER BY total_revenue ASC)  AS lowest_rank
    FROM monthly_revenue
)
SELECT 
    year1, month1, total_revenue,
    CASE 
        WHEN highest_rank = 1 THEN 'Highest Month'
        WHEN lowest_rank  = 1 THEN 'Lowest Month'
    END AS category
FROM ranked
WHERE highest_rank = 1 OR lowest_rank = 1
ORDER BY total_revenue DESC;


-- Q4: What is the year-over-year (YoY) revenue growth rate?
WITH yearly AS (
    SELECT 
        YEAR(order_purchase_timestamp) AS year1,
        ROUND(SUM(COALESCE(payment_value,0)),2) AS revenue 
    FROM olist 
    WHERE order_status = 'delivered'
    GROUP BY YEAR(order_purchase_timestamp)
)
SELECT 
    year1,
    revenue,
    LAG(revenue) OVER(ORDER BY year1) AS previous_year,
    ROUND(
        ((revenue - LAG(revenue) OVER(ORDER BY year1)) /
         NULLIF(LAG(revenue) OVER(ORDER BY year1), 0)) * 100
    ,2) AS yoy_growth_pct
FROM yearly
ORDER BY year1;


-- Q5: What is the day-over-day (DoD) revenue growth rate?
WITH daily_revenue AS (
    SELECT 
        DATE(order_purchase_timestamp) AS order_date,
        ROUND(SUM(COALESCE(payment_value,0)),2) AS revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY DATE(order_purchase_timestamp)
),
calc AS (
    SELECT *,
           LAG(revenue) OVER (ORDER BY order_date) AS previous_day
    FROM daily_revenue
)
SELECT 
    order_date,
    revenue,
    previous_day,
    ROUND(
        ((revenue - previous_day) / NULLIF(previous_day, 0)) * 100
    ,2) AS dod_growth_pct
FROM calc
ORDER BY order_date;


-- Q6: Which states contribute the most revenue?
WITH order_level AS (
    SELECT 
        order_id,
        customer_state,
        SUM(COALESCE(payment_value,0)) AS order_revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY order_id, customer_state
)
SELECT 
    customer_state,
    ROUND(SUM(order_revenue),2) AS revenue
FROM order_level
GROUP BY customer_state
ORDER BY revenue DESC;


-- Q7: Which cities generate high order volume but low revenue (top city)?
WITH city_metrics AS (
    SELECT 
        customer_city,
        COUNT(DISTINCT order_id) AS order_volume,
        SUM(COALESCE(payment_value,0)) AS total_revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_city
)
SELECT 
    customer_city,
    order_volume,
    ROUND(total_revenue,2) AS revenue,
    ROUND(total_revenue / order_volume,2) AS avg_order_value
FROM city_metrics
ORDER BY order_volume DESC
LIMIT 1;


-- Q8: What percentage of revenue comes from top 10% customers?
WITH customer_revenue AS (
    SELECT 
        customer_id,
        SUM(COALESCE(payment_value,0)) AS revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_id
),
ranked AS (
    SELECT *,
           NTILE(10) OVER (ORDER BY revenue DESC) AS revenue_decile
    FROM customer_revenue
)
SELECT 
    ROUND(
        SUM(CASE WHEN revenue_decile = 1 THEN revenue END) * 100.0 
        / SUM(revenue)
    ,2) AS top_10_pct_revenue_share
FROM ranked;


-- Q9: Are there specific months where sales drastically drop (>20% MoM decline)?
WITH monthly AS (
    SELECT 
        DATE_FORMAT(order_purchase_timestamp,'%Y-%m') AS year_month,
        SUM(COALESCE(payment_value,0)) AS revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY DATE_FORMAT(order_purchase_timestamp,'%Y-%m')
),
calc AS (
    SELECT *,
           LAG(revenue) OVER (ORDER BY year_month) AS previous_month
    FROM monthly
)
SELECT 
    year_month,
    ROUND(revenue,2) AS revenue,
    ROUND(previous_month,2) AS previous_month,
    ROUND(
        ((revenue - previous_month) / NULLIF(previous_month, 0)) * 100
    ,2) AS mom_change_pct
FROM calc
WHERE ((revenue - previous_month) / NULLIF(previous_month, 0)) * 100 < -20
ORDER BY year_month;


-- Q10: What is the average order value (AOV)?
WITH order_level AS (
    SELECT 
        order_id,
        SUM(COALESCE(payment_value,0)) AS order_revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY order_id
)
SELECT 
    ROUND(AVG(order_revenue),2) AS average_order_value
FROM order_level;


-- ============================================================
-- PART 2: CUSTOMER BEHAVIOR
-- ============================================================

-- Q11: How many unique customers does the company have?
SELECT 
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM olist
WHERE order_status = 'delivered';


-- Q12: What is the repeat purchase rate?
WITH customer_orders AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT 
    ROUND(
        COUNT(CASE WHEN order_count > 1 THEN 1 END) * 100.0
        / COUNT(*)
    ,2) AS repeat_customer_pct
FROM customer_orders;


-- Q13: How many customers purchased more than once?
SELECT 
    customer_unique_id,
    COUNT(DISTINCT order_id) AS order_count
FROM olist 
WHERE order_status = 'delivered'
GROUP BY customer_unique_id
HAVING COUNT(DISTINCT order_id) > 1
ORDER BY order_count DESC;


-- Q14: What is the average time gap between repeat purchases?
WITH ordered_purchases AS (
    SELECT 
        customer_unique_id,
        order_id,
        DATE(order_purchase_timestamp) AS order_date,
        LAG(DATE(order_purchase_timestamp)) 
            OVER (PARTITION BY customer_unique_id 
                  ORDER BY order_purchase_timestamp) AS previous_order_date
    FROM olist
    WHERE order_status = 'delivered'
),
gap_calculation AS (
    SELECT 
        customer_unique_id,
        DATEDIFF(order_date, previous_order_date) AS gap_days
    FROM ordered_purchases
    WHERE previous_order_date IS NOT NULL
)
SELECT 
    ROUND(AVG(gap_days),2) AS avg_days_between_repeat_purchases
FROM gap_calculation;


-- Q15: Which states have the highest number of repeat customers?
WITH customer_state_orders AS (
    SELECT 
        customer_unique_id,
        customer_state,
        COUNT(DISTINCT order_id) AS order_count
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id, customer_state
)
SELECT 
    customer_state,
    COUNT(*) AS repeat_customers
FROM customer_state_orders
WHERE order_count > 1
GROUP BY customer_state
ORDER BY repeat_customers DESC;


-- Q16: What is customer lifetime value (CLV)?
WITH lifetime AS (
    SELECT 
        customer_unique_id,
        SUM(COALESCE(payment_value,0)) AS revenue
    FROM olist 
    WHERE order_status = 'delivered' 
    GROUP BY customer_unique_id
)
SELECT 
    ROUND(AVG(revenue),2) AS avg_clv, 
    ROUND(MAX(revenue),2) AS max_clv, 
    ROUND(MIN(revenue),2) AS min_clv
FROM lifetime;


-- Q17: Are high-spending customers concentrated in specific regions?
WITH customer_clv AS (
    SELECT 
        customer_unique_id,
        customer_state,
        SUM(COALESCE(payment_value,0)) AS total_revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id, customer_state
),
ranked AS (
    SELECT *,
           NTILE(10) OVER (ORDER BY total_revenue DESC) AS revenue_decile
    FROM customer_clv
)
SELECT 
    customer_state,
    COUNT(CASE WHEN revenue_decile = 1 THEN 1 END) AS high_spenders,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(CASE WHEN revenue_decile = 1 THEN 1 END) * 100.0 / COUNT(*)
    ,2) AS high_spender_pct
FROM ranked
GROUP BY customer_state
ORDER BY high_spender_pct DESC;


-- Q18: Do customers from metro cities spend more than rural areas?
WITH cust AS (
    SELECT 
        customer_unique_id, 
        customer_city, 
        SUM(COALESCE(payment_value,0)) AS revenue 
    FROM olist 
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id, customer_city
),
classified AS (
    SELECT *, 
        CASE 
            WHEN customer_city IN ('sao paulo','rio de janeiro','belo horizonte',
                                   'brasilia','curitiba','porto alegre') 
            THEN 'Metro' 
            ELSE 'Rural' 
        END AS area_type 
    FROM cust
)
SELECT 
    area_type, 
    ROUND(SUM(revenue),2) AS total_spending,
    ROUND(AVG(revenue),2) AS avg_spending, 
    COUNT(*) AS total_customers 
FROM classified 
GROUP BY area_type;


-- Q19: What is the churn rate?
WITH cus AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT 
    COUNT(CASE WHEN order_count = 1 THEN 1 END) AS churned_customers,
    COUNT(*) AS total_customers,
    ROUND(
        COUNT(CASE WHEN order_count = 1 THEN 1 END) * 100.0
        / COUNT(*)
    ,2) AS churn_rate_pct
FROM cus;


-- Q20: Which customer segment generates the most profit?
WITH customer_profit AS (
    SELECT 
        customer_unique_id,
        SUM(payment_value - freight_value) AS estimated_profit
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
),
segmented AS (
    SELECT *,
           NTILE(3) OVER (ORDER BY estimated_profit DESC) AS segment_rank
    FROM customer_profit
)
SELECT 
    CASE 
        WHEN segment_rank = 1 THEN 'High Profit'
        WHEN segment_rank = 2 THEN 'Medium Profit'
        ELSE 'Low Profit'
    END AS customer_segment,
    ROUND(SUM(estimated_profit),2) AS total_profit,
    COUNT(*) AS total_customers
FROM segmented
GROUP BY customer_segment
ORDER BY total_profit DESC;


-- ============================================================
-- PART 3: PRODUCT & CATEGORY ANALYSIS
-- ============================================================

-- Q21: Which product categories generate the highest revenue?
SELECT 
    product_category_name_english,
    ROUND(SUM(COALESCE(payment_value,0)),2) AS revenue
FROM olist
WHERE order_status = 'delivered'
  AND product_category_name_english IS NOT NULL
GROUP BY product_category_name_english
ORDER BY revenue DESC;


-- Q22: Which categories have high sales volume but low revenue?
WITH category_metrics AS (
    SELECT 
        product_category_name_english,
        COUNT(DISTINCT order_id) AS order_volume,
        SUM(COALESCE(payment_value,0)) AS total_revenue
    FROM olist
    WHERE order_status = 'delivered'
      AND product_category_name_english IS NOT NULL
    GROUP BY product_category_name_english
)
SELECT 
    product_category_name_english,
    order_volume,
    ROUND(total_revenue,2) AS revenue,
    ROUND(total_revenue / order_volume,2) AS avg_order_value
FROM category_metrics
ORDER BY order_volume DESC;


-- Q23: Which categories have the highest cancellation rate?
SELECT 
    product_category_name_english,
    ROUND(
        COUNT(CASE WHEN order_status = 'canceled' THEN 1 END) * 100.0
        / COUNT(*)
    ,2) AS cancellation_rate_pct
FROM olist
WHERE product_category_name_english IS NOT NULL
GROUP BY product_category_name_english
ORDER BY cancellation_rate_pct DESC;


-- Q24: Which product categories have the longest average delivery time?
SELECT 
    product_category_name_english,
    ROUND(
        AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))
    ,2) AS avg_delivery_days
FROM olist
WHERE order_status = 'delivered'
  AND product_category_name_english IS NOT NULL
GROUP BY product_category_name_english
ORDER BY avg_delivery_days DESC;


-- Q25: Which categories have the lowest average customer ratings?
SELECT 
    product_category_name_english,
    ROUND(AVG(review_score),2) AS avg_rating
FROM olist
WHERE product_category_name_english IS NOT NULL
GROUP BY product_category_name_english
ORDER BY avg_rating ASC;


-- ============================================================
-- PART 4: SELLER PERFORMANCE
-- ============================================================

-- Q26: Which sellers generate the highest revenue?
SELECT 
    seller_id,
    ROUND(SUM(COALESCE(payment_value,0)),2) AS revenue
FROM olist
WHERE order_status = 'delivered'
GROUP BY seller_id
ORDER BY revenue DESC;


-- Q27: Which sellers have the highest cancellation rate?
SELECT 
    seller_id,
    ROUND(
        COUNT(CASE WHEN order_status = 'canceled' THEN 1 END) * 100.0
        / COUNT(*)
    ,2) AS cancellation_rate_pct
FROM olist
GROUP BY seller_id
ORDER BY cancellation_rate_pct DESC;


-- Q28: What is the average delivery time per seller?
SELECT 
    seller_id,
    ROUND(
        AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))
    ,2) AS avg_delivery_days
FROM olist
WHERE order_status = 'delivered'
GROUP BY seller_id
ORDER BY avg_delivery_days DESC;


-- Q29: Which sellers have the lowest average review score?
SELECT 
    seller_id,
    ROUND(AVG(review_score),2) AS avg_rating
FROM olist
GROUP BY seller_id
ORDER BY avg_rating ASC;


-- Q30: What percentage of total revenue comes from the top 20 sellers?
WITH seller_rev AS (
    SELECT 
        seller_id,
        SUM(COALESCE(payment_value,0)) AS revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY seller_id
),
ranked AS (
    SELECT *,
           DENSE_RANK() OVER (ORDER BY revenue DESC) AS rnk
    FROM seller_rev
)
SELECT 
    ROUND(
        SUM(CASE WHEN rnk <= 20 THEN revenue END) * 100.0
        / SUM(revenue)
    ,2) AS top20_sellers_revenue_pct
FROM ranked;


-- ============================================================
-- PART 5: DELIVERY & LOGISTICS
-- ============================================================

-- Q31: What is the average delivery time (purchase → delivery)?
SELECT 
    ROUND(
        AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))
    ,2) AS avg_delivery_days
FROM olist
WHERE order_status = 'delivered';


-- Q32: What percentage of orders are delivered late (actual > estimated)?
SELECT 
    ROUND(
        COUNT(CASE 
            WHEN order_delivered_customer_date > order_estimated_delivery_date 
            THEN 1 END) * 100.0
        / COUNT(*)
    ,2) AS late_delivery_pct
FROM olist
WHERE order_status = 'delivered';


-- Q33: Which states experience the highest delivery delays?
SELECT 
    customer_state,
    ROUND(
        AVG(DATEDIFF(order_delivered_customer_date, order_estimated_delivery_date))
    ,2) AS avg_delay_days
FROM olist
WHERE order_status = 'delivered'
GROUP BY customer_state
ORDER BY avg_delay_days DESC;


-- Q34: Do delayed orders receive lower review scores?
SELECT 
    CASE 
        WHEN order_delivered_customer_date > order_estimated_delivery_date
        THEN 'Delayed'
        ELSE 'On Time'
    END AS delivery_status,
    ROUND(AVG(review_score),2) AS avg_rating
FROM olist
WHERE order_status = 'delivered'
GROUP BY delivery_status;


-- Q35: Does freight value correlate with delivery time?
SELECT 
    ROUND(AVG(freight_value),2) AS avg_freight,
    ROUND(
        AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))
    ,2) AS avg_delivery_days
FROM olist
WHERE order_status = 'delivered';


-- ============================================================
-- PART 6: REVIEWS & CUSTOMER SATISFACTION
-- ============================================================

-- Q36: What is the overall average review score?
SELECT 
    ROUND(AVG(review_score),2) AS avg_review_score
FROM olist;


-- Q37: What percentage of orders received 5-star ratings?
SELECT 
    ROUND(
        COUNT(CASE WHEN review_score = 5 THEN 1 END) * 100.0
        / COUNT(*)
    ,2) AS five_star_pct
FROM olist;


-- Q38: Which states have the lowest average review score?
SELECT 
    customer_state,
    ROUND(AVG(review_score),2) AS avg_rating
FROM olist
GROUP BY customer_state
ORDER BY avg_rating ASC;


-- Q39: Do repeat customers give higher ratings than first-time buyers?
WITH cust AS (
    SELECT 
        customer_unique_id,
        COUNT(DISTINCT order_id) AS orders
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY customer_unique_id
)
SELECT 
    CASE WHEN c.orders > 1 THEN 'Repeat' ELSE 'New' END AS customer_type,
    ROUND(AVG(o.review_score),2) AS avg_rating
FROM olist o
JOIN cust c ON o.customer_unique_id = c.customer_unique_id
GROUP BY customer_type;


-- Q40: Is there a relationship between product price and review score?
SELECT 
    review_score,
    ROUND(AVG(payment_value),2) AS avg_spend
FROM olist
WHERE order_status = 'delivered'
GROUP BY review_score
ORDER BY review_score;

-- ============================================================
-- END OF ANALYSIS
-- ============================================================
