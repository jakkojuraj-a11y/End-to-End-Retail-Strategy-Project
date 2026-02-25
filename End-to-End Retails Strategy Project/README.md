# 🛒 Olist Brazilian E-Commerce — End-to-End Data Analytics Project

## 📋 Project Overview

This project performs a **comprehensive end-to-end analysis** of the **Olist Brazilian E-Commerce Dataset**, covering the full data pipeline from raw data ingestion through cleaning, SQL-based business analysis, and interactive dashboard visualization.

The goal is to uncover actionable insights across **customer behavior**, **seller performance**, **delivery logistics**, **product trends**, and **revenue patterns** to support data-driven decision-making.

---

## 🧰 Tech Stack

| Tool | Purpose |
|------|---------|
| **Python (Pandas, NumPy, Seaborn, Matplotlib)** | Data loading, merging, cleaning, EDA |
| **MySQL** | Business problem queries & advanced analytics |
| **Power BI** | Interactive dashboard & visual reporting |
| **Jupyter Notebook** | Development environment |

---

## 📁 Project Structure

```
Olist_End_to_End_project/
│
├── 01_Data_Exploration_and_Merging.ipynb   # Phase 1: Load & merge 9 CSV files
├── 02_Data_Cleaning_and_Export.ipynb        # Phase 2: Clean data, export to MySQL
├── 03_SQL_Business_Analysis.sql            # Phase 3: 40 SQL business queries
├── 04_PowerBI_Dashboard.pbix               # Phase 4: Interactive Power BI report
├── 05_Project_Presentation.pptx            # Phase 5: Project presentation (12 slides)
├── 06_Medium_Blog_Post.md                  # Phase 6: Medium blog article
├── Olist_Cleaned_Dataset.csv               # Cleaned master dataset (119K rows × 44 cols)
└── README.md                               # This file
```

---

## 🔄 Data Pipeline

```
9 Raw CSV Files
    ↓  (Pandas merge on order_id, customer_id, product_id, seller_id)
Master DataFrame (119,151 rows × 44 columns)
    ↓  (Missing value handling, type downcasting, feature engineering)
Clean Dataset → Exported to MySQL
    ↓  (40 business queries with CTEs, window functions, aggregations)
SQL Analysis Results
    ↓  (Connected to Power BI)
Interactive Dashboard (04_PowerBI_Dashboard.pbix)
```

---

## 📊 Key Business Questions Answered

### 1️⃣ Revenue & Growth
- Total revenue, monthly/yearly trends (MoM, YoY, DoD growth rates)
- Revenue by state and city, top 10% customer revenue share
- Average Order Value (AOV), months with drastic sales drops

### 2️⃣ Customer Behavior
- Unique customer count, repeat purchase rate (~3%)
- Average time gap between repeat purchases
- Customer Lifetime Value (CLV), churn rate (~97%)
- Metro vs rural spending comparison
- Customer segmentation by profit (High / Medium / Low)

### 3️⃣ Product & Category Analysis
- Revenue-driving product categories
- Categories with high volume but low revenue
- Cancellation rates and delivery times by category
- Customer ratings by product category

### 4️⃣ Seller Performance
- Top revenue-generating sellers
- Seller cancellation rates and delivery times
- Lowest-rated sellers
- Revenue concentration (top 20 sellers' share)

### 5️⃣ Delivery & Logistics
- Average delivery time (~12 days)
- Late delivery percentage (~7.6%)
- Delivery delays by state
- Impact of delays on review scores

### 6️⃣ Reviews & Customer Satisfaction
- Overall average review score (4.09/5)
- 5-star rating percentage
- Repeat vs new customer ratings
- Price vs review score relationship

---

## 🔑 Key Findings

- **São Paulo (SP)** is the dominant revenue-contributing state
- **~97% of customers are one-time buyers** — very low repeat purchase rate
- **Delayed deliveries correlate with lower review scores** — logistics directly impacts satisfaction
- **Top 10% of customers contribute ~17% of total revenue**
- **Metro city customers spend more on average** than rural customers
- **Health & beauty, watches, and bed/bath/table** are top revenue categories

---

## ⚙️ Setup & Reproduction

### Prerequisites
- Python 3.x with `pandas`, `numpy`, `seaborn`, `matplotlib`, `missingno`, `sqlalchemy`, `pymysql`
- MySQL Server
- Power BI Desktop (for `.pbix` file)

### Steps

1. **Run `01_Data_Exploration_and_Merging.ipynb`** — Loads and merges the 9 raw Olist CSV files
2. **Run `02_Data_Cleaning_and_Export.ipynb`** — Cleans data, engineers features, exports to MySQL
3. **Open `03_SQL_Business_Analysis.sql` in MySQL** — Execute the 40 business queries
4. **Open `04_PowerBI_Dashboard.pbix`** in Power BI — View the interactive dashboard
5. **Open `05_Project_Presentation.pptx`** — View the 12-slide animated presentation

---

## 📝 Data Source

The dataset is from the [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) available on Kaggle. It contains ~100K orders from 2016–2018 across multiple Brazilian marketplaces.

---

## 👤 Author

**Jakkoju Vikasraj**

---
