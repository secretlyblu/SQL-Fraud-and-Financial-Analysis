--Create database 
CREATE DATABASE SQL_Fintech_Transactions; 

-- Create Table 
CREATE TABLE Transactions ( 
          Transaction_id  INT PRIMARY KEY, 
          Transaction_date  DATE, 
          Transaction_time  TIME, 
          Customer_id  INT, 
          Age  INT, 
          Account_type  TEXT, 
          Region  TEXT, 
          Customer_since  DATE, 
          Transaction_type  TEXT, 
          Channel  TEXT, 
          Merchant_category TEXT, 
          Amount  FLOAT, 
          Fee  FLOAT, 
          Is_international  TEXT,
          Status  TEXT, 
          Is_fraud  TEXT
);

--VIEW DATA
SELECT * FROM transactions
LIMIT 10;

SELECT COUNT(*) FROM  transactions;
-- DATA CLEANING 
--FINDING NULL Values 
SELECT * FROM transactions
    WHERE Transaction_id  IS NULL 
       OR Transaction_date  IS NULL 
       OR Transaction_time  IS NULL 
       OR Customer_id IS NULL 
       OR Age  IS NULL 
       OR Account_type  IS NULL 
       OR Region  IS  NULL 
       OR Customer_since  IS NULL 
       OR Transaction_type  IS NULL 
       OR Channel  IS NULL 
       OR Merchant_category IS NULL 
       OR Amount  IS NULL 
       OR Fee  IS NULL 
       OR Is_international  IS NULL
       OR Status  IS NULL 
       OR Is_fraud  IS NULL;
-- Counting NULL values by column
WITH --COMBINING RESULTS INTO ONE TABLE
    'Age' AS (SELECT count(*) filter (where age is null) AS 'Age'
     FROM  transactions),
    'Channel' AS (SELECT count(*) filter (where channel is null) AS 'Channel'
     FROM  transactions),
    'Merchant_category'  AS (SELECT count(*) filter (where merchant_category is null) AS  'Merchant_category'
     FROM  transactions),
    'Amount' AS (SELECT count(*) filter (where amount is null) AS 'Amount'
     FROM  transactions )
SELECT * FROM 'Age', 'Channel', 'Merchant_category', 'Amount';

--Fix NULL Values 
-- rather than delete rows with Nulls we will look to fill it with existing data given that some customers have multiple records
--Fixing "Age" Column by looking up customer_id

SELECT customer_id from Transactions
where age is null;


SELECT age from transactions where customer_id = 5038;
Update transactions set age = 49 where customer_id = 5038 AND age is null;
SELECT age from transactions where customer_id = 6091;
Update transactions set age = 39 where customer_id = 6091 AND age is null;
SELECT age from transactions where customer_id = 6188;
Update transactions set age = 26 where customer_id = 6188 AND age is null;
SELECT age from transactions where customer_id = 6101;
Update transactions set age = 41 where customer_id = 6101 AND age is null;
SELECT age from transactions where customer_id = 5904;
Update transactions set age = 35 where customer_id = 5904 AND age is null;
SELECT age from transactions where customer_id = 6123;
Update transactions set age = 47 where customer_id = 6123 AND age is null;
--Deleting records with Null Values
Delete FROM Transactions WHERE age IS NULL
        OR Channel IS NULL
        or Merchant_category IS NULL
        or Amount IS NULL;

-- Looking for casing mismatches
SELECT account_type , count(*) from transactions
GROUP BY account_type;

SELECT region , count(*) from transactions
GROUP BY region;

SELECT transaction_type , count(*) from transactions
GROUP BY transaction_type;

SELECT channel , count(*) from transactions
GROUP BY channel;

SELECT merchant_category , count(*) from transactions
GROUP BY merchant_category;

SELECT is_international , count(*) from transactions
GROUP BY is_international;

SELECT is_fraud , count(*) from transactions
GROUP BY is_fraud;

SELECT status , count(*) from transactions
GROUP BY status;

-- fixing casing mismatches
Update transactions set channel = 'Mobile App' 
where channel = 'mobile app';
Update transactions set channel = 'POS' 
where channel = 'pos';
Update transactions set channel = 'Web' 
where channel = 'web';

-- Looking for outliers
SELECT 
      min(amount) as 'Min Trans',max(amount) as 'Max Trans', round(AVG(amount),2) as 'Avg Trans'
FROM transactions;  

-- understanding data percentile
WITH ordered_amounts AS (
    SELECT
        amount,
        ROW_NUMBER() OVER (ORDER BY amount) AS row_num,
        COUNT(*) OVER () AS total_rows
    FROM transactions
)
SELECT
    MIN(CASE WHEN row_num >= total_rows * 0.25 THEN amount END) AS Q1,
    MIN(CASE WHEN row_num >= total_rows * 0.75 THEN amount END) AS Q3
FROM ordered_amounts;


/*Calc boundaries 
IQR = Q3 - Q1    554.71 - 90.33 = 464.37
Lower =  Q1 - (1.5 * IQR)     90.33 - (1.5 * 464.37) = - 606.225
Upper =  Q3 + (1.5 * IQR)     554.71 + (1.5 * 464.37) = 1251.265
*/

SELECT * FROM Transactions
WHERE amount < - 606.225
   OR amount > 1251.265;

   SELECT account_type, count(*), round(AVG(amount)) FROM Transactions
   WHERE amount > 1251.265
     GROUP BY account_type 

     -- DATA EXPLORATION
--total transactions
SELECT COUNT(*) FROM transactions;

--unique customers
SELECT  COUNT(DISTINCT customer_id) AS 'UNIQUE_CUST' FROM transactions;

-- total volume
SELECT ROUND(SUM(amount),2) FROM transactions;

--date range
SELECT MIN(transaction_date) FROM transactions;
SELECT MAX(transaction_date) FROM transactions;

--BUSINESS ANALYSIS
--What is the overall fraud rate, and what is it by channel?
        -- tot occurrence of fraud
        SELECT COUNT(*) 
        FROM transactions
        where is_fraud = 'Yes';
        
       
        
                  --rate of overall fraud
        SELECT 100.0 * COUNT(*) FILTER (WHERE is_fraud = 'Yes')/COUNT(*) AS Fraud_Rate FROM transactions; 
        
        RESULT
        Fraud_Rate
        2
        
                -- share by channel of fraud cases 
        SELECT
            channel,
            COUNT(*) AS fraud_cases,
            ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_fraud
        FROM transactions
        WHERE is_fraud = 'Yes'
        GROUP BY channel
        ORDER BY fraud_cases DESC;
        
 --Which merchant categories have the highest fraud rate?
SELECT
merchant_category,
COUNT(*) AS fraud_cases,
ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_fraud
FROM transactions
WHERE is_fraud = 'Yes'
GROUP BY merchant_category
ORDER BY fraud_cases DESC;

--What is the total fee revenue by account type?
SELECT account_type, SUM(fee) FROM transactions
GROUP BY account_type;

--How does fraud rate compare for international vs. domestic transactions?
SELECT
    is_international,
    COUNT(*) AS fraud_cases,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_fraud
FROM transactions
WHERE is_fraud = 'Yes'
GROUP BY is_international
ORDER BY fraud_cases DESC;

--Which time of day (morning, evening, overnight) has the most fraud? 
SELECT
    CASE
      when transaction_time BETWEEN '07:00:00' AND '14:59:59' Then "Morning"
      when transaction_time BETWEEN '15:00:00' AND '22:59:59' Then "Evening"
    Else "Overnight"
  End As 'Timeframes', count(*) as Trans_ct
From transactions
  where is_fraud ='Yes'
  GROUP BY 1
  order by Trans_ct desc;

  --Which age groups spend the most on average?
SELECT
CASE
  when age BETWEEN 18 and 34 then "18-34"
  when age BETWEEN 35 and 49 then "35-49"
  when age BETWEEN 50 and 64 then "50-64"
  when age >= 65 then "65+"
end as age_group, 
   round(avg (amount),2) AS Avg_spend 
From transactions
GROUP BY 1 --repeats case
ORDER BY Avg_spend  desc;

--Who are the top 10 customers by total transaction volume?
SELECT customer_id, round(sum(amount),2) AS Trans_Amt FROM transactions
GROUP BY customer_id
ORDER BY Trans_Amt DESC
limit 10;



--What is the decline rate by region?

SELECT region, count(*), ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_Dec FROM transactions
WHERE status = 'Declined'
GROUP BY region; 


--What is the average transaction amount by account type and transaction type?

SELECT account_type, ROUND(avg(amount),2)
FROM transactions
GROUP BY account_type;


SELECT transaction_type, ROUND(avg(amount),2)
FROM transactions
GROUP BY transaction_type;

--end of project

