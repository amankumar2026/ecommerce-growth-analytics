# Power BI Dashboard: Build Guide

This guide takes you from an empty Power BI file to a finished 4-page dashboard. Allow about 2 hours the first time.

Everything you need is in this folder:

| File | What it is |
|---|---|
| `data/*.csv` | Six clean tables exported from PostgreSQL |
| `measures.dax` | Every DAX measure and calculated column, with comments |
| `theme.json` | Colour theme |

**Check your work as you go.** The "Expected values" tables below were calculated from the same data with SQL and Python. If your card shows a different number, something in the model is wrong (usually a relationship).

> The DAX in `measures.dax` uses standard patterns but was written without Power BI Desktop available to run it. If a measure shows an error, read the message, compare with the expected value, and fix it. Doing that is good interview preparation.

---

## Step 0. Install Power BI Desktop

Free from the Microsoft Store (search "Power BI Desktop"). Windows only.

## Step 1. Load the data

1. **Home > Get data > Text/CSV**. Load each of the six files in `data/`. Click **Load** (not Transform) for each.
2. Open **Table view** (left sidebar) and check the row counts:

| Table | Rows | One row is |
|---|---|---|
| `fact_orders` | 96,211 | a delivered order |
| `fact_order_items` | 109,880 | an item sold |
| `dim_customer` | 93,104 | a customer |
| `dim_category` | 74 | a product category |
| `dim_date` | 608 | a calendar day |
| `cohort_retention` | 181 | a cohort in a given month |

3. Check the data types (select a column, **Column tools > Data type**):
   - `order_date`, `date`, `first_order_date`, `cohort_month`, `month_start`: **Date**
   - `revenue`, `freight`, `price`: **Decimal number**
   - `delivered_late`, `review_score`, `delivery_days`: **Whole number**

## Step 2. Build the data model (star schema)

Open **Model view**. Delete any relationships Power BI created automatically, then create these by dragging one column onto the other:

| From (one side) | To (many side) |
|---|---|
| `dim_date[date]` | `fact_orders[order_date]` |
| `dim_date[date]` | `fact_order_items[order_date]` |
| `dim_customer[customer_unique_id]` | `fact_orders[customer_unique_id]` |
| `dim_customer[customer_unique_id]` | `fact_order_items[customer_unique_id]` |
| `dim_category[product_category]` | `fact_order_items[product_category]` |

All five should be **one-to-many (1:*)**, **single** cross-filter direction. `cohort_retention` has no relationship; it is a stand-alone table.

Then:

- Select `dim_date` > **Table tools > Mark as date table** > choose `date`. Time intelligence measures need this.
- In `dim_date`, select `month_name` > **Column tools > Sort by column > month_number**, so months sort Jan, Feb, Mar instead of alphabetically.

**Why a star schema?** Fact tables hold the numbers (orders, items). Dimension tables hold the things you filter and group by (date, customer, category). A filter on a dimension flows to the facts, so one slicer can control every visual.

## Step 3. Add the measures and columns

1. **Home > Enter data > Load** to create an empty table. Rename it `_Measures`.
2. Open `measures.dax`. For each measure: **Modeling > New measure**, paste it, press Enter.
3. Add the three calculated columns at the bottom of the file to `fact_orders` (**Table tools > New column**).
4. Format: select a measure, then in **Measure tools** set percentages to **Percentage** with 1 decimal, and revenue to **Whole number** with a thousands separator.

## Step 4. Apply the theme

**View > Themes > Browse for themes > `theme.json`**.

---

## Page 1. Executive Overview

Purpose: the health of the business in one look.

| Visual | Fields |
|---|---|
| 6 cards across the top | `Total Revenue`, `Total Orders`, `Total Customers`, `Avg Order Value`, `Avg Review Score`, `Late Delivery %` |
| Line chart (wide) | X-axis: `dim_date[month_start]`, Y-axis: `Total Revenue` |
| Column chart | X-axis: `dim_date[month_start]`, Y-axis: `MoM Growth %` |
| Line chart | X-axis: `dim_date[month_start]`, Y-axis: `Running Revenue` |
| Slicers | `dim_date[year]`, `dim_customer[customer_state]` |

Expected values with no filters:

| Measure | Value |
|---|---|
| Total Revenue | 13,181,027 |
| Total Orders | 96,211 |
| Total Customers | 93,104 |
| Avg Order Value | 137.00 |
| Avg Review Score | 4.16 |
| Late Delivery % | 6.8% |
| Total Revenue, year = 2017 | 5,962,902 |
| Total Revenue, year = 2018 | 7,218,125 |
| Total Revenue for November 2017 | 987,765 |
| MoM Growth % for November 2017 | 52.4% |
| YoY Growth % for August 2018 | 51.2% |

With the state slicer set to **SP**: Total Revenue 5,057,498, Total Orders 40,408, Late Delivery % 4.5%, Avg Review Score 4.25.

## Page 2. Products and Regions

Purpose: what sells and where.

| Visual | Fields |
|---|---|
| Bar chart (top 10) | Y-axis: `dim_category[category_name]`, X-axis: `Item Revenue`. In the Filters pane set `category_name` to **Top N = 10** by `Item Revenue` |
| Table | `category_name`, `Items Sold`, `Item Revenue`, `Category Revenue Share %` |
| Bar chart or filled map | `dim_customer[customer_state]`, `Total Revenue` |
| Column chart | X-axis: `dim_date[weekday_name]` (sort by `weekday_number`), Y-axis: `Total Orders` |
| Slicer | `dim_date[year]` |

Expected values:

| Check | Value |
|---|---|
| Health Beauty revenue | 1,229,558 (9.3% share) |
| Watches Gifts revenue | 1,163,466 |
| Bed Bath Table revenue | 1,022,956 |
| Sports Leisure revenue | 952,840 |
| Computers Accessories revenue | 888,056 |
| SP revenue | 5,057,498 (38.4% share) |
| RJ revenue | 1,751,458 |
| MG revenue | 1,548,205 |
| Item Revenue total | 13,181,027 (must equal Total Revenue) |

> State figures here use each customer's most recent state (from `dim_customer`). The SQL query in `03_sales_performance.sql` uses the state on each order, so SP is 5,055,587 there. The gap is a few customers who moved.

## Page 3. Customers and Retention

Purpose: do customers come back, and who is valuable?

| Visual | Fields |
|---|---|
| 4 cards | `Customers`, `Repeat Rate %`, `Returning Revenue %`, `Revenue per Customer` |
| Bar chart | Y-axis: `dim_customer[segment]`, X-axis: `Customers` |
| Bar chart | Y-axis: `dim_customer[segment]`, X-axis: `Customer Revenue` |
| Stacked column chart | X-axis: `dim_date[month_start]`, Y-axis: `Total Orders`, Legend: `fact_orders[Customer Type]` |
| Matrix (cohort heatmap) | Rows: `cohort_retention[cohort_month]`, Columns: `cohort_retention[months_since_first]`, Values: `Retention %` |

For the matrix: in the Filters pane set `months_since_first` to **is greater than 0** (month 0 is always 100% and hides the colours). Then **Format > Cell elements > Background color** on, to get a heatmap.

Expected values:

| Measure | Value |
|---|---|
| Customers | 93,104 |
| Repeat Customers | 2,789 |
| Repeat Rate % | 3.0% |
| Returning Revenue | 384,569 |
| Returning Revenue % | 2.9% |
| Revenue per Customer | 141.57 |

| Segment | Customers | Customer Revenue |
|---|---|---|
| New big spenders | 14,441 | 3,856,546 |
| Lost big spenders | 13,745 | 3,800,304 |
| Need attention | 18,023 | 2,344,789 |
| Lost low value | 22,501 | 1,254,650 |
| New customers | 21,605 | 1,199,383 |
| Loyal, cooling off | 1,594 | 401,478 |
| Champions | 1,195 | 323,877 |

> Do not put a date slicer on this page. `Customers` and `Repeat Rate %` count rows in `dim_customer`, and a date filter does not flow from a fact table back to a dimension, so they would not change.

## Page 4. Delivery and Satisfaction

Purpose: how delivery affects reviews.

| Visual | Fields |
|---|---|
| 4 cards | `Avg Delivery Days`, `Late Delivery %`, `Avg Review Score`, `Bad Review %` |
| Column chart | X-axis: `fact_orders[Delivery Status]`, Y-axis: `Avg Review Score` |
| Column chart | X-axis: `fact_orders[Delivery Time Band]`, Y-axis: `Avg Review Score` |
| Line chart | X-axis: `dim_date[month_start]`, Y-axis: `Late Delivery %` |
| Bar chart | Y-axis: `dim_customer[customer_state]`, X-axis: `Late Delivery %` |
| Slicer | `dim_date[year]` |

Expected values:

| Measure | Value |
|---|---|
| Avg Delivery Days | 12.5 |
| Late Orders | 6,531 |
| Late Delivery % | 6.8% |
| Avg Review Score | 4.16 |
| Bad Review % | 12.8% |
| Avg Review Score, On time | 4.29 |
| Avg Review Score, Late | 2.27 |

---

## Finishing touches

- Give each page a title text box and one line stating the main finding (for example "97% of customers never order again").
- Align visuals with **Format > Align** and keep the same slicer position on every page.
- Add a tooltip or subtitle saying the period: January 2017 to August 2018.
- Save as `ecommerce_dashboard.pbix` in this folder.
- Take a screenshot of each page and save them in `reports/dashboard/`. The main README has a section ready to show them.

## Questions an interviewer may ask about the dashboard

**What is the difference between a measure and a calculated column?**
A column is calculated once per row when the data loads and is stored. A measure is calculated when a visual needs it, for whatever filters are active. Use a column to group or slice by (Delivery Status). Use a measure for a number that must respond to filters (Total Revenue).

**What does CALCULATE do?**
It evaluates a measure after changing the filters. `CALCULATE ( [Total Orders], fact_orders[delivered_late] = 1 )` counts orders with the extra condition that they were late.

**What does ALL do?**
It removes filters. In `Category Revenue Share %` it removes the category filter so the bottom number is revenue for every category.

**Why DIVIDE and not `/`?**
DIVIDE returns blank when the bottom number is zero, instead of an error.

**Why did you use a star schema?**
It is simple, fast and predictable. Filters flow one way, from dimensions to facts, so every visual responds to slicers in the same way.

**Why is cohort retention a pre-calculated table?**
Cohort logic is much clearer in SQL than in DAX, and it does not need to respond to slicers. I calculated it once in PostgreSQL and loaded the result.
