# How I Analyzed 100K+ E-Commerce Orders to Uncover Hidden Business Insights — A Complete Data Analytics Project

*A deep dive into the Olist Brazilian E-Commerce Dataset using Python, SQL, and Power BI*

---

> "Without data, you're just another person with an opinion." — W. Edwards Deming

---

## Introduction

Every time you click "Buy Now" on an e-commerce platform, you create a data point. Multiply that by millions of users, and you have a goldmine of insights waiting to be discovered.

I recently completed an **end-to-end data analytics project** on the **Olist Brazilian E-Commerce Dataset** — one of the most comprehensive real-world e-commerce datasets available on Kaggle. It contains **100,000+ orders** placed between **2016 and 2018** across multiple Brazilian marketplaces.

The project wasn't just about writing queries or making charts. It was about asking the **right business questions** and transforming raw transactional data into **actionable intelligence**.

In this blog, I'll walk you through the entire journey — from merging 9 raw CSV files into a single master dataset, to cleaning 119K+ rows of messy data, to writing 40+ advanced SQL queries, and finally building an interactive Power BI dashboard.

Let's dive in.

---

## 🧩 The Dataset

The Olist dataset is a **real anonymized dataset** from Brazil's largest department store marketplace. It connects small businesses across Brazil to online sales channels through a single contract.

The dataset consists of **9 interconnected tables**:

| Table | Description |
|-------|-------------|
| `olist_orders_dataset` | Order timestamps, status, estimated delivery |
| `olist_customers_dataset` | Customer location and unique IDs |
| `olist_order_items_dataset` | Product details per order, prices, freight |
| `olist_products_dataset` | Product dimensions, category, photos |
| `olist_sellers_dataset` | Seller location information |
| `olist_order_payments_dataset` | Payment type, installments, value |
| `olist_order_reviews_dataset` | Review scores and comments |
| `product_category_name_translation` | Portuguese → English category names |
| `olist_geolocation_dataset` | ZIP code coordinates (lat/lng) |

This isn't a toy dataset. It reflects real-world messiness — missing values, duplicate keys, mismatched geolocation entries, and orders in various states of completion.

---

## 🎯 The Problem Statement

Despite generating **millions in revenue**, Olist faces several operational pain points:

- **Delayed deliveries** impacting customer experience
- **High logistics costs** eating into margins
- **Low review scores** across certain product categories
- **High cancellation rates** eroding trust
- **Regional delivery inefficiency** across Brazil's vast geography
- **Revenue concentration** risk — over-reliance on a few customers and sellers

My goal was to **diagnose these problems with data** and propose actionable recommendations.

---

## 🔧 The Tech Stack

I used a full-stack analytics approach:

- **Python** (Pandas, NumPy, Seaborn, Matplotlib, Missingno) — for data wrangling, cleaning, and exploratory analysis
- **MySQL** — for structured business analysis using advanced SQL
- **Power BI** — for interactive dashboarding and visual storytelling
- **Jupyter Notebook** — as the development environment
- **SQLAlchemy** — as the Python-to-MySQL bridge

Why multiple tools? Because each one excels at something different. **Python** is great for flexible data manipulation. **SQL** is unbeatable for structured aggregations and window functions. **Power BI** brings it all to life with interactivity.

---

## 🔄 Phase 1 — Data Merging (Python)

The first challenge was merging 9 separate CSV files into a single analysis-ready DataFrame.

```python
import pandas as pd

customers = pd.read_csv("olist_customers_dataset.csv")
orders = pd.read_csv("olist_orders_dataset.csv")
order_items = pd.read_csv("olist_order_items_dataset.csv")
products = pd.read_csv("olist_products_dataset.csv")
sellers = pd.read_csv("olist_sellers_dataset.csv")
payments = pd.read_csv("olist_order_payments_dataset.csv")
reviews = pd.read_csv("olist_order_reviews_dataset.csv")
category = pd.read_csv("product_category_name_translation.csv")
geolocation = pd.read_csv("olist_geolocation_dataset.csv")
```

I merged them step by step using the appropriate foreign keys:

```python
Olist = orders.merge(customers, on="customer_id", how="left")
Olist = Olist.merge(order_items, on="order_id", how="left")
Olist = Olist.merge(products, on="product_id", how="left")
Olist = Olist.merge(sellers, on="seller_id", how="left")
Olist = Olist.merge(payments, on="order_id", how="left")
Olist = Olist.merge(reviews, on="order_id", how="left")
Olist = Olist.merge(category, on="product_category_name", how="left")
```

For geolocation, I aggregated coordinates by `city` and `state` before merging to avoid the many-to-many explosion:

```python
geo_agg = geolocation.groupby(
    ['geolocation_state', 'geolocation_city']
)[['geolocation_lat', 'geolocation_lng']].mean().reset_index()

Olist = Olist.merge(
    geo_agg,
    left_on=['customer_state', 'customer_city'],
    right_on=['geolocation_state', 'geolocation_city'],
    how='left'
)
```

**Result:** A master DataFrame with **119,151 rows × 44 columns** — ready for analysis.

---

## 🧹 Phase 2 — Data Cleaning

Real-world data is never clean. Here's what I found:

| Column | Missing Values |
|--------|---------------|
| `order_approved_at` | 177 |
| `order_delivered_carrier_date` | 2,086 |
| `order_delivered_customer_date` | 3,421 |
| `order_item_id` (+ related) | 833 |
| `review_creation_date` | 96,431 |

### What I Did:

**1. Visualized missing data patterns** using `missingno`:

```python
import missingno as msno
msno.matrix(df, figsize=(12, 6))
```

This immediately revealed that delivery-related columns had correlated missing values — orders that were never shipped naturally have no delivery dates.

**2. Optimized data types** to reduce memory usage:

```python
float_columns = ['price', 'freight_value', 'product_weight_g',
                 'product_length_cm', 'product_height_cm',
                 'product_width_cm', 'payment_value',
                 'geolocation_lat', 'geolocation_lng']

for col in float_columns:
    df[col] = pd.to_numeric(df[col], downcast='float')
```

This brought memory usage down from **40+ MB to ~30 MB** — a 25% reduction.

**3. Engineered new features:**

```python
df['delivery_days'] = (
    pd.to_datetime(df['order_delivered_customer_date']) -
    pd.to_datetime(df['order_purchase_timestamp'])
).dt.days
```

**4. Exported to MySQL** for SQL analysis:

```python
from sqlalchemy import create_engine
import os

engine = create_engine(
    f"mysql+pymysql://root:{os.getenv('MYSQL_PASSWORD')}@127.0.0.1:3306/olist_database"
)
df.to_sql("olist", engine, if_exists="replace", index=False)
```

---

## 📊 Phase 3 — SQL Business Analysis (40 Queries)

This is where the real insights emerged. I wrote **40 advanced SQL queries** organized into 6 business domains.

### 1. Revenue & Growth

```sql
-- Month-over-Month revenue growth with LAG window function
WITH monthly AS (
    SELECT
        DATE_FORMAT(order_purchase_timestamp,'%Y-%m') AS year_month,
        ROUND(SUM(COALESCE(payment_value,0)),2) AS revenue
    FROM olist
    WHERE order_status = 'delivered'
    GROUP BY DATE_FORMAT(order_purchase_timestamp,'%Y-%m')
)
SELECT
    year_month, revenue,
    LAG(revenue) OVER(ORDER BY year_month) AS prev_month,
    ROUND(
        ((revenue - LAG(revenue) OVER(ORDER BY year_month)) /
         NULLIF(LAG(revenue) OVER(ORDER BY year_month), 0)) * 100
    ,2) AS mom_growth_pct
FROM monthly
ORDER BY year_month;
```

**Key finding:** Revenue grew consistently from 2016 to mid-2018, with **November 2017 showing the highest spike** — likely driven by Black Friday.

### 2. Customer Behavior

```sql
-- Customer Lifetime Value (CLV)
WITH lifetime AS (
    SELECT customer_unique_id,
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
```

**Shocking finding:** The **repeat purchase rate is only ~3%**. That means **97% of customers never come back**. This is the single biggest red flag in the dataset.

### 3. Metro vs Rural Spending

```sql
WITH classified AS (
    SELECT *,
        CASE
            WHEN customer_city IN ('sao paulo','rio de janeiro',
                 'belo horizonte','brasilia','curitiba','porto alegre')
            THEN 'Metro' ELSE 'Rural'
        END AS area_type
    FROM olist
    WHERE order_status = 'delivered'
)
SELECT area_type,
       ROUND(AVG(payment_value),2) AS avg_spending,
       COUNT(DISTINCT customer_unique_id) AS customers
FROM classified
GROUP BY area_type;
```

**Finding:** Metro customers spend **more per order on average** and represent a disproportionate share of total revenue.

### 4. Delivery Impact on Reviews

```sql
SELECT
    CASE
        WHEN order_delivered_customer_date > order_estimated_delivery_date
        THEN 'Delayed' ELSE 'On Time'
    END AS delivery_status,
    ROUND(AVG(review_score),2) AS avg_rating
FROM olist
WHERE order_status = 'delivered'
GROUP BY delivery_status;
```

**Finding:** On-time deliveries receive an average rating of **4.3 ⭐**, while delayed deliveries drop to **3.5 ⭐** — a **0.8-point penalty** for being late. This proves that **logistics directly drives customer satisfaction**.

---

## 📈 Phase 4 — Power BI Dashboard

The final piece was bringing everything together in an **interactive Power BI dashboard**. This allowed stakeholders to:

- Filter by date range, state, or product category
- Track KPIs (revenue, order volume, review scores) in real time
- Drill down into specific sellers or regions
- Compare on-time vs delayed delivery performance

The dashboard transforms static numbers into a **living, breathing analytical tool**.

---

## 🔍 Key Findings — The Full Picture

After analyzing 119,151 records across 40 queries, here are the most impactful insights:

### 📊 Revenue
- **Total revenue: R$ 16M+** from delivered orders
- **São Paulo dominates** — contributing the most revenue of any state
- **Top 10% of customers generate ~17%** of total revenue
- **November 2017** was the peak month (Black Friday effect)

### 👥 Customers
- **96,096 unique customers** in the dataset
- **Only ~3% repeat** — most are one-time buyers
- **Churn rate: ~97%** — an alarming retention problem
- **Average gap between repeat purchases: ~90 days**

### 🚚 Delivery
- **Average delivery time: ~12 days**
- **~7.6% of orders arrive late**
- **Delayed orders = lower ratings** (3.5 vs 4.3 stars)
- **Remote states face the worst delays**

### 🏪 Sellers
- **Top 20 sellers** account for a significant share of revenue — concentration risk
- **Some sellers consistently underperform** on delivery and ratings
- **Seller quality directly correlates** with customer review scores

### 📦 Products
- **Health & Beauty, Watches, Bed/Bath/Table** are top revenue categories
- **Heavier products** tend to have longer delivery times
- **Electronics categories** consistently receive lower ratings

---

## 💡 Recommendations

Based on the analysis, here are **5 actionable recommendations** for Olist:

### 1. 🔄 Fix the Retention Crisis
With a 97% churn rate, customer retention is the #1 priority. Implement:
- Post-purchase email sequences
- Loyalty programs with points/rewards
- Personalized product recommendations based on purchase history

### 2. 🚚 Optimize Regional Logistics
Partner with **regional carriers** in high-delay states. Set **realistic delivery estimates** — customers hate broken promises more than longer delivery times.

### 3. 📊 Diversify the Seller Base
Too much revenue depends on too few sellers. Actively **onboard and incentivize** mid-tier sellers to grow. This reduces concentration risk and improves marketplace resilience.

### 4. ⭐ Implement Seller Scorecards
Create a transparent **seller performance monitoring system** with metrics on:
- Cancellation rate
- Average delivery time
- Mean review score

Penalize consistently underperforming sellers.

### 5. 🎯 Double Down on Metro Markets
Metro cities are high-value, high-volume customers. Focus marketing spend here while simultaneously **investing in rural delivery infrastructure** for long-term growth.

---

## 🛠️ What I Learned

This project taught me more than any course ever could. Here are my key takeaways:

1. **Real data is messy.** Missing values aren't random — they follow patterns. Understanding *why* data is missing is as important as handling it.

2. **SQL is underrated.** Window functions (LAG, NTILE, DENSE_RANK), CTEs, and CASE expressions can answer incredibly complex business questions in a single query.

3. **The insight is in the combination.** Revenue numbers alone are meaningless. But revenue × delivery speed × review scores? That's where the story lives.

4. **Every metric tells a story.** A 97% churn rate isn't just a number — it's a business survival problem hiding in plain sight.

5. **Visualization isn't optional.** A well-designed dashboard communicates in 5 seconds what a 100-row table can't convey in 5 minutes.

---

## 📁 Project Structure

```
Olist_End_to_End_project/
├── 01_Data_Exploration_and_Merging.ipynb   # Phase 1: Load & merge 9 CSV files
├── 02_Data_Cleaning_and_Export.ipynb        # Phase 2: Clean data, export to MySQL
├── 03_SQL_Business_Analysis.sql            # Phase 3: 40 SQL business queries
├── 04_PowerBI_Dashboard.pbix               # Phase 4: Interactive Power BI report
├── 05_Project_Presentation.pptx            # Phase 5: Animated presentation
├── 06_Medium_Blog_Post.md                  # Phase 6: This blog article
├── Olist_Cleaned_Dataset.csv               # Cleaned master dataset
└── README.md                               # Project documentation
```

---

## 🔗 Connect With Me

If you found this analysis interesting, feel free to connect:

- **LinkedIn:** [Jakkoju Vikasraj]
- **GitHub:** [Your GitHub Profile]
- **Kaggle:** [Your Kaggle Profile]

---

## Final Thoughts

Data analytics isn't about fancy tools or complex algorithms. It's about **asking the right questions**, **being honest about what the data says**, and **translating numbers into decisions**.

This Olist project covered the full lifecycle — from raw CSVs to a polished dashboard. Every step revealed something new about how a real e-commerce business operates, struggles, and can improve.

If you're building your data analytics portfolio, I highly recommend picking a **real-world dataset** and going end-to-end. Don't stop at EDA. Write the SQL. Build the dashboard. Tell the story.

The data is always talking. You just have to learn how to listen.

---

*Thank you for reading! If this helped you, please give it a 👏 and share it with someone who's learning data analytics. Happy analyzing! 🚀*

---

**Tags:** `#DataAnalytics` `#SQL` `#Python` `#PowerBI` `#ECommerce` `#DataScience` `#Portfolio` `#BusinessIntelligence`
