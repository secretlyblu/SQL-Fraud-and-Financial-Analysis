# Fintech Transactions Analysis SQL Project

## Project Overview

**Project Title**: Fintech Transactions Analysis (Fraud, Fee Revenue & Customer Behavior)
**Level**: Beginner to Intermediate
**Database**: `SQL_Fintech_Transactions` (SQLite)
**Dataset**: Synthetic digital payment data (3,000 transactions, calendar year 2024). No real customer information is used.

This project demonstrates SQL skills used by fintech data analysts to clean, explore, and analyze payment transaction data. A digital bank wants to detect and reduce fraud, understand where its fee revenue comes from, and learn how customers use different channels and account types. The project covers database setup, data cleaning (nulls, inconsistent casing, outliers), exploratory data analysis (EDA), and business-driven SQL queries.

## Business Problem

Fraud costs digital banks money and customer trust, while fee revenue depends on how different customer segments transact. Leadership needs to know:

- Where is fraud happening (channel, merchant category, domestic vs. international, time of day)?
- Which account types generate the most fee revenue?
- Which customer segments transact the most, and where are transactions being declined?

## Objectives

1. **Set up a transactions database**: Create and populate a table with the transaction data.
2. **Data Cleaning**: Fill nulls using each customer's other records, delete records that cannot be fixed, standardize inconsistent text, and review outliers.
3. **Exploratory Data Analysis (EDA)**: Understand transaction counts, customer counts, dollar volume, and date range.
4. **Business Analysis**: Use SQL to answer specific questions about fraud, revenue, customer spending, and declines.

## Dataset

| Column | Description |
|---|---|
| transaction_id | Unique ID for each transaction (primary key) |
| transaction_date | Date of the transaction |
| transaction_time | Time of the transaction |
| customer_id | Customer identifier (customers can have multiple transactions) |
| age | Customer age |
| account_type | Basic, Premium, or Business |
| region | Customer region (Northeast, Southeast, Midwest, Southwest, West) |
| customer_since | Date the customer opened their account |
| transaction_type | Purchase, Transfer, Withdrawal, or Bill Payment |
| channel | Mobile App, Web, POS, or ATM |
| merchant_category | Category of the merchant or transaction (e.g., Groceries, Travel, Crypto Exchange) |
| amount | Transaction amount in dollars |
| fee | Fee charged to the customer |
| is_international | Whether the transaction was international (Yes/No) |
| status | Completed or Declined |
| is_fraud | Whether the transaction was flagged as fraud (Yes/No) |

## Project Structure

### 1. Database Setup

```sql
CREATE DATABASE SQL_Fintech_Transactions;

CREATE TABLE Transactions (
    Transaction_id    INT PRIMARY KEY,
    Transaction_date  DATE,
    Transaction_time  TIME,
    Customer_id       INT,
    Age               INT,
    Account_type      TEXT,
    Region            TEXT,
    Customer_since    DATE,
    Transaction_type  TEXT,
    Channel           TEXT,
    Merchant_category TEXT,
    Amount            FLOAT,
    Fee               FLOAT,
    Is_international  TEXT,
    Status            TEXT,
    Is_fraud          TEXT
);
```

After importing the CSV, the record count was confirmed:

```sql
SELECT COUNT(*) FROM Transactions;
```

**Result**: 3,000 rows, as expected.

### 2. Data Cleaning

**Step 1: Identify null values**

```sql
SELECT * FROM Transactions
WHERE Transaction_id IS NULL
   OR Transaction_date IS NULL
   OR Transaction_time IS NULL
   OR Customer_id IS NULL
   OR Age IS NULL
   OR Account_type IS NULL
   OR Region IS NULL
   OR Customer_since IS NULL
   OR Transaction_type IS NULL
   OR Channel IS NULL
   OR Merchant_category IS NULL
   OR Amount IS NULL
   OR Fee IS NULL
   OR Is_international IS NULL
   OR Status IS NULL
   OR Is_fraud IS NULL;
```

**Result**: 8 nulls each in `age`, `channel`, `merchant_category`, and `amount`.

To see the null counts for each column in one table, each count is placed in its own CTE and then combined:

```sql
WITH null_age AS (
        SELECT COUNT(*) FILTER (WHERE age IS NULL) AS Age FROM Transactions),
     null_channel AS (
        SELECT COUNT(*) FILTER (WHERE channel IS NULL) AS Channel FROM Transactions),
     null_category AS (
        SELECT COUNT(*) FILTER (WHERE merchant_category IS NULL) AS Merchant_category FROM Transactions),
     null_amount AS (
        SELECT COUNT(*) FILTER (WHERE amount IS NULL) AS Amount FROM Transactions)
SELECT * FROM null_age, null_channel, null_category, null_amount;
```

| Age | Channel | Merchant_category | Amount |
|---|---|---|---|
| 8 | 8 | 8 | 8 |

**Step 2: Fix null ages using the customer's other records**

Customers often appear in more than one transaction, so a missing age can be filled from another row for the same customer. There were 7 distinct customers with a missing age, and 6 could be fixed this way.

```sql
-- Find customers with a missing age
SELECT customer_id FROM Transactions WHERE age IS NULL;

-- Check the customer's other records, then fill the null
SELECT age FROM Transactions WHERE customer_id = 5038;
UPDATE Transactions SET age = 49 WHERE customer_id = 5038 AND age IS NULL;
```

**Step 3: Delete records that cannot be reliably fixed**

`channel`, `merchant_category`, and `amount` cannot be estimated from other records, so the remaining rows with nulls were removed.

```sql
DELETE FROM Transactions
WHERE age IS NULL
   OR Channel IS NULL
   OR Merchant_category IS NULL
   OR Amount IS NULL;
```

This removed 25 rows, leaving **2,975 records**.

**Step 4: Check for inconsistent casing**

Each text column was grouped to look for the same value spelled in different cases:

```sql
SELECT channel, COUNT(*) FROM Transactions GROUP BY channel;
-- Repeated for account_type, region, transaction_type, merchant_category,
-- is_international, is_fraud, and status
```

Only `channel` had inconsistencies:

| channel | count |
|---|---|
| ATM | 646 |
| Mobile App | 1008 |
| POS | 674 |
| Web | 632 |
| mobile app | 6 |
| pos | 7 |
| web | 2 |

These were standardized:

```sql
UPDATE Transactions SET channel = 'Mobile App' WHERE channel = 'mobile app';
UPDATE Transactions SET channel = 'POS' WHERE channel = 'pos';
UPDATE Transactions SET channel = 'Web' WHERE channel = 'web';
```

**Step 5: Look for outliers in transaction amount**

```sql
SELECT MIN(amount) AS 'Min Trans', MAX(amount) AS 'Max Trans', ROUND(AVG(amount), 2) AS 'Avg Trans'
FROM Transactions;
```

| Min Trans | Max Trans | Avg Trans |
|---|---|---|
| 5.92 | 14,192.09 | 499.21 |

The quartiles were calculated with a window function:

```sql
WITH ordered_amounts AS (
    SELECT
        amount,
        ROW_NUMBER() OVER (ORDER BY amount) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM Transactions
)
SELECT
    MIN(CASE WHEN row_num >= total_rows * 0.25 THEN amount END) AS Q1,
    MIN(CASE WHEN row_num >= total_rows * 0.75 THEN amount END) AS Q3
FROM ordered_amounts;
```

| Q1 | Q3 |
|---|---|
| 90.33 | 554.71 |

Using the IQR method:

- IQR = Q3 - Q1 = 554.71 - 90.33 = 464.38
- Lower bound = Q1 - (1.5 x IQR) = -606.24 (no transaction can be below zero, so there are no low outliers)
- Upper bound = Q3 + (1.5 x IQR) = 1,251.27

```sql
SELECT * FROM Transactions
WHERE amount < -606.225 OR amount > 1251.265;
```

**Result**: 277 of 2,975 records (about 9.3%) fall above the upper bound. Breaking them down by account type:

```sql
SELECT account_type, COUNT(*), ROUND(AVG(amount))
FROM Transactions
WHERE amount > 1251.265
GROUP BY account_type;
```

| account_type | count | avg amount |
|---|---|---|
| Basic | 82 | 1,854 |
| Business | 108 | 3,162 |
| Premium | 87 | 2,295 |

These outliers were **kept** in the data. Large transactions are expected for Business accounts, they appear across all account types, and large amounts are a useful signal for fraud analysis.

### 3. Data Exploration

1. **Total transactions**

```sql
SELECT COUNT(*) FROM Transactions;
```
**Result**: 2,975

2. **Unique customers**

```sql
SELECT COUNT(DISTINCT customer_id) AS UNIQUE_CUST FROM Transactions;
```
**Result**: 1,109

3. **Total volume (dollars)**

```sql
SELECT ROUND(SUM(amount), 2) FROM Transactions;
```
**Result**: $1,485,137.82

4. **Date range**

```sql
SELECT MIN(transaction_date) FROM Transactions;
SELECT MAX(transaction_date) FROM Transactions;
```
**Result**: 2024-01-01 to 2024-12-30

### 4. Data Analysis & Findings

The queries below answer 9 of the 12 planned business questions.

1. **What is the overall fraud rate, and how is fraud distributed by channel?**

```sql
-- Total fraud cases
SELECT COUNT(*) FROM Transactions WHERE is_fraud = 'Yes';

-- Overall fraud rate
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE is_fraud = 'Yes') / COUNT(*), 2) AS Fraud_Rate
FROM Transactions;

-- Share of fraud cases by channel
SELECT
    channel,
    COUNT(*) AS fraud_cases,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_fraud
FROM Transactions
WHERE is_fraud = 'Yes'
GROUP BY channel
ORDER BY fraud_cases DESC;
```

| channel | fraud_cases | pct_of_fraud |
|---|---|---|
| Mobile App | 24 | 34.29 |
| Web | 18 | 25.71 |
| POS | 17 | 24.29 |
| ATM | 11 | 15.71 |

2. **Which merchant categories account for the most fraud cases?**

```sql
SELECT
    merchant_category,
    COUNT(*) AS fraud_cases,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_fraud
FROM Transactions
WHERE is_fraud = 'Yes'
GROUP BY merchant_category
ORDER BY fraud_cases DESC;
```

| merchant_category | fraud_cases | pct_of_fraud |
|---|---|---|
| Bank Transfer | 21 | 30.00 |
| Utilities | 13 | 18.57 |
| Cash | 6 | 8.57 |
| Travel | 6 | 8.57 |
| Crypto Exchange | 4 | 5.71 |
| Online Retail | 4 | 5.71 |
| Electronics | 3 | 4.29 |
| Entertainment | 3 | 4.29 |
| Gas | 3 | 4.29 |
| Groceries | 3 | 4.29 |
| Dining | 2 | 2.86 |
| Healthcare | 2 | 2.86 |

3. **What is the total fee revenue by account type?**

```sql
SELECT account_type, SUM(fee) FROM Transactions
GROUP BY account_type;
```

| account_type | SUM(fee) |
|---|---|
| Basic | 7,292.51 |
| Business | 3,893.46 |
| Premium | 2,670.58 |

4. **How are fraud cases split between international and domestic transactions?**

```sql
SELECT
    is_international,
    COUNT(*) AS fraud_cases,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_fraud
FROM Transactions
WHERE is_fraud = 'Yes'
GROUP BY is_international
ORDER BY fraud_cases DESC;
```

| is_international | fraud_cases | pct_of_fraud |
|---|---|---|
| No | 61 | 87.14 |
| Yes | 9 | 12.86 |

5. **Which time of day has the most fraud?**

Because payments happen 24/7, the time frames cover the full day with no gaps:

- **Morning**: 7:00 AM to 2:59 PM
- **Evening**: 3:00 PM to 10:59 PM
- **Overnight**: 11:00 PM to 6:59 AM

```sql
SELECT
    CASE
        WHEN transaction_time BETWEEN '07:00:00' AND '14:59:59' THEN 'Morning'
        WHEN transaction_time BETWEEN '15:00:00' AND '22:59:59' THEN 'Evening'
        ELSE 'Overnight'
    END AS Timeframes,
    COUNT(*) AS Trans_ct
FROM Transactions
WHERE is_fraud = 'Yes'
GROUP BY 1
ORDER BY Trans_ct DESC;
```

| Timeframes | Trans_ct |
|---|---|
| Evening | 27 |
| Morning | 26 |
| Overnight | 17 |

6. **Which age groups spend the most on average?**

```sql
SELECT
    CASE
        WHEN age BETWEEN 18 AND 34 THEN '18-34'
        WHEN age BETWEEN 35 AND 49 THEN '35-49'
        WHEN age BETWEEN 50 AND 64 THEN '50-64'
        WHEN age >= 65 THEN '65+'
    END AS age_group,
    ROUND(AVG(amount), 2) AS Avg_spend
FROM Transactions
GROUP BY 1
ORDER BY Avg_spend DESC;
```

| age_group | Avg_spend |
|---|---|
| 35-49 | 513.42 |
| 50-64 | 493.77 |
| 18-34 | 491.54 |
| 65+ | 351.83 |

7. **Who are the top 10 customers by total transaction volume?**

```sql
SELECT customer_id, ROUND(SUM(amount), 2) AS Trans_Amt
FROM Transactions
GROUP BY customer_id
ORDER BY Trans_Amt DESC
LIMIT 10;
```

| customer_id | Trans_Amt |
|---|---|
| 6091 | 24,363.96 |
| 5638 | 14,806.67 |
| 6070 | 11,259.77 |
| 5834 | 10,655.47 |
| 5721 | 9,678.21 |
| 6191 | 9,624.67 |
| 5933 | 9,363.85 |
| 5284 | 9,342.96 |
| 5779 | 9,150.23 |
| 6073 | 8,808.33 |

8. **How are declined transactions distributed by region?**

```sql
SELECT region, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_Dec
FROM Transactions
WHERE status = 'Declined'
GROUP BY region;
```

| region | declined | pct_of_Dec |
|---|---|---|
| Midwest | 25 | 22.32 |
| Northeast | 20 | 17.86 |
| Southeast | 19 | 16.96 |
| Southwest | 19 | 16.96 |
| West | 29 | 25.89 |

9. **What is the average transaction amount by account type and by transaction type?**

```sql
SELECT account_type, ROUND(AVG(amount), 2)
FROM Transactions
GROUP BY account_type;

SELECT transaction_type, ROUND(AVG(amount), 2)
FROM Transactions
GROUP BY transaction_type;
```

| account_type | avg amount |
|---|---|
| Basic | 336.34 |
| Premium | 538.89 |
| Business | 1,062.05 |

| transaction_type | avg amount |
|---|---|
| Bill Payment | 221.60 |
| Purchase | 326.31 |
| Withdrawal | 393.44 |
| Transfer | 1,206.83 |

## Findings

- **Dataset Summary**: After cleaning, the data holds **2,975 transactions** from **1,109 customers** between January 1 and December 30, 2024, with a total volume of **$1,485,137.82** and an average transaction of **$499.21**. About 9.3% of transactions (277) were large outliers above $1,251.27.
- **Overall Fraud**: There were **70 fraud cases**, a fraud rate of about **2.35%** of transactions.
- **Fraud by Channel**: Mobile App accounts for the largest share of fraud cases (**34.29%**), followed by Web (**25.71%**), POS (**24.29%**), and ATM (**15.71%**). Because channels have different transaction counts, share of fraud is not the same as fraud rate. Dividing each channel's fraud cases by its transaction count gives a rate of about **2.84% for Web**, **2.50% for POS**, **2.37% for Mobile App**, and **1.70% for ATM**, so Web is the riskiest channel per transaction.
- **Fraud by Merchant Category**: **Bank Transfer** (30%) and **Utilities** (18.57%) account for nearly half of all fraud cases, followed by Cash and Travel (8.57% each).
- **International vs. Domestic**: **87.14%** of fraud cases were domestic and **12.86%** were international. 
- **Time of Day**: Evening had the most fraud cases (**27**), followed by Morning (**26**) and Overnight (**17**).
- **Fee Revenue**: The bank earned about **$13,856.55** in fees. Basic accounts generated the most (**$7,292.51, 52.6%**), followed by Business (**$3,893.46, 28.1%**) and Premium (**$2,670.58, 19.3%**).
- **Spending by Age**: The **35-49** group has the highest average transaction (**$513.42**), while the **65+** group has the lowest (**$351.83**).
- **Top Customers**: The top 10 customers moved about **$117,054**, roughly **7.9%** of total volume. Customer **6091** is the largest at **$24,363.96**.
- **Declines**: There were **112 declined transactions** (about 3.8% of all transactions). The West has the largest share of declines (**25.89%**), followed by the Midwest (**22.32%**). 
- **Transaction Size**: Business accounts have the highest average transaction (**$1,062.05**) compared with Premium (**$538.89**) and Basic (**$336.34**). Transfers are the largest transaction type on average (**$1,206.83**), far above Bill Payments (**$221.60**).

## Reports

- **Fraud Summary**: Fraud share by channel, merchant category, domestic vs. international, and time of day.
- **Revenue Summary**: Fee revenue by account type and average transaction amount by account and transaction type.
- **Customer Summary**: Average spend by age group, top 10 customers by volume, and declines by region.

## Recommendations

1. Add extra verification for **Web** and **bank transfer** transactions, since Web has the highest fraud rate and Bank Transfer has the largest share of fraud cases.
2. Monitor the largest-volume customers (such as customer 6091) and high-value transfers for unusual activity, since large amounts are more common in Business accounts and may mask fraud.
3. Investigate why the **West** and **Midwest** have the most declined transactions.
4. Review the fee structure for Premium accounts, which generate the least fee revenue despite higher average transaction sizes than Basic accounts.

## Assumptions & Limitations

- The data is **synthetic** and created for portfolio purposes, so findings do not reflect a real financial institution.
- Missing ages were filled from the same customer's other transactions. Records with missing channel, merchant category, or amount were deleted (25 rows removed in total).
- Outliers in `amount` were reviewed using the IQR method but **kept**, since large transactions are expected for some account types and are relevant to fraud analysis.
- Volume refers to **dollar volume** (`SUM(amount)`), and declined transactions are included in the volume and count figures.
- Time frames and age groups are analyst-defined ranges, documented above.
- Several questions report each group's **share of fraud or declines**, which depends on how many transactions the group has. A rate (cases divided by that group's total transactions) is needed to compare groups of different sizes, and is noted as a next step where not yet calculated.
- 9 of the 12 planned questions were completed. The remaining three (monthly volume trend with month-over-month change, customers with repeat fraud, and each transaction compared with the customer's own average) are left as future work.

## Conclusion

This project walks through the SQL workflow of a fintech data analyst: database setup, null handling, standardizing inconsistent text, outlier review, exploratory analysis, and business-driven queries using aggregation, CASE WHEN, and window functions. The results can help a digital bank prioritize fraud controls, understand its revenue by account type, and identify high-value customers.

## How to Use

1. **Clone the Repository**: Clone this project from GitHub.
2. **Set Up the Database**: Create the `Transactions` table with the script above and import `fintech_transactions.csv`.
3. **Run the Queries**: Use the queries in the project's `.sql` file to reproduce the analysis.
4. **Explore and Modify**: Adjust the age groups, time frames, or filters, or complete the remaining three business questions.

## Tools Used

- SQL (SQLite)
- GitHub

## Author - Diane Gordon

This project is part of my data analytics portfolio, showcasing SQL skills for fintech and financial services analyst roles. Feel free to reach out with questions or feedback.

- **LinkedIn**: (https://www.linkedin.com/in/diagordon/)
- **GitHub**: (https://github.com/secretlyblu?tab=repositories)
