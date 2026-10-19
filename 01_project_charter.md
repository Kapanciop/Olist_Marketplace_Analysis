# BrightCart Marketplace: Diagnosing Uneven Growth Across Regions, Customers, and Delivery Performance

> **Note:** BrightCart Marketplace is a fictional company created for this portfolio project. All data comes from the public Olist Brazilian E-Commerce dataset (Kaggle).

## 1. Business Problem

BrightCart's leadership has noticed that growth is uneven: some regions are expanding while others stall, many customers appear to purchase only once, and delivery problems may be affecting customer satisfaction. If these issues persist, the company risks wasting acquisition spend on customers who never return and losing ground in weaker regions. Leadership needs a data-backed view of where growth is strongest and weakest, how well customers are retained, and whether delivery performance is linked to customer satisfaction, so they can decide where to focus resources.

## 2. Project Objectives

1. **Measure** repeat purchase rate overall and by region, and identify factors associated with customers not returning (e.g., delivery delays, review scores).
2. **Compare** delivery performance (delivery time, late-delivery rate) between growing and stagnant or declining regions.
3. **Identify** which regions and product categories are driving or dragging revenue growth over time.
4. **Recommend** where management should focus resources, based on the evidence.

## 3. Stakeholders

| Stakeholder | Cares about | Decision they would make with this analysis |
|---|---|---|
| **VP of Sales** | Consistent revenue growth across regions | Which regions and categories get more sales and marketing investment |
| **VP of Delivery Operations** | Where delivery delays originate | Which regions or sellers need logistics fixes or carrier changes |
| **Head of Customer Experience** | Customer satisfaction and repeat purchases | Whether to prioritize retention programs, and where |

## 4. Core Business Questions

| # | Objective | Question |
|---|---|---|
| Q1 | #1 Repeat purchases | Which states had the highest and lowest repeat purchase **rate** in 2017 and 2018? |
| Q2 | #2 Delivery vs growth | How do average delivery time and late-delivery rate differ between the fastest-growing and slowest-growing states? |
| Q3 | #3 Growth drivers | Which states and product categories contributed the most to revenue growth from 2017 to 2018, and which declined? |
| Q4 | #4 Where to focus | Which states combine high order volume with low review scores or high late-delivery rates? |

*Supporting questions (seasonality, product performance, customer segments) will be added after data exploration.*

## 5. Core KPIs

| KPI | Definition | Primary stakeholder |
|---|---|---|
| **Late Delivery Rate** | Delivered orders where the actual delivery date was after the estimated delivery date ÷ total delivered orders | VP of Delivery Operations |
| **Repeat Purchase Rate** | Unique customers (`customer_unique_id`) with 2+ orders ÷ total unique customers | Head of Customer Experience |
| **New Customers per Month** | Unique customers whose first-ever order falls in that month (broken out by state) | VP of Sales |

*Added during the project: Monthly Revenue, Average Order Value, Average Review Score, Average Delivery Time.*

## 6. Key Definitions

- **Growth** = % change in total revenue, comparing **Jan–Aug 2017 vs. Jan–Aug 2018**. Verified during data exploration: the last delivered orders are in August 2018 (the 20 orders after that were canceled or in transit), so comparing the same months avoids penalizing 2018 for being a partial year.
- **Customer** = a unique person, identified by `customer_unique_id`. Do **not** use `customer_id`, which is generated per order and would make nearly every customer look like a one-time buyer.
- **Delivered order** = order with a status of `delivered` and a recorded delivery date.

## 7. Scope and Known Limitations

- The dataset has **no cost or profit data**. Performance is assessed using revenue, freight, payments, review scores, and delivery performance, not margin.
- The data can show **associations**, not causes. Findings will use language such as "associated with" and "suggests," not "caused by."
- The dataset is a sample of one marketplace over roughly 2016–2018; 2016 data is sparse and 2018 is a partial year.
- BrightCart is a fictional framing of real, anonymized data.

## 8. Deliverables

| Deliverable | Status |
|---|---|
| Project charter (this document) | Done |
| Data cleaning and decision log (`data_cleaning_log.md`) | Done |
| SQL scripts: cleaning views and analysis (`02_analysis.sql`) | Done |
| Power BI dashboard, 2 pages (`dashboard/`) | Done |
| Findings and recommendations (README) | Done |
| GitHub README and portfolio case study | Done |
| Data dictionary and ER diagram | Scoped down to a short data model summary in the README |
| Excel workbook (pivots, KPIs) | Not included in this version |

*Supporting questions (seasonality, product performance, customer segments) were scoped out of this version.*
