/* VOCABULARY
person_age					Age
person_income				Annual Income
person_home_ownership		Home ownership
person_emp_length			Employment length (in years)
loan_intent					Loan intent (PERSONAL, EDUCATION, MEDICAL, VENTURE, 
							HOME IMPROVEMENT, DEBT CONSOLIDATION)
loan_grade					Loan grade (A - extremely low to G - High)
loan_amnt					Loan amount
loan_int_rate				Interest rate
loan_status					Loan status (0 is non default 1 is default)
loan_percent_income			Percent income
cb_person_default_on_file	Historical default (Has borrower defaulted before?)
cb_person_cred_hist_length	Credit history length (how long an account has been open)
*/ 
-- DELETE FROM loans;
-- 1. EDA
-- check data quality after import
select * from loans
limit 5;

select count(*) from loans; -- 32581

--- check null values in columns
select * 
from loans
where person_age is NULL; --none

select Count(*)
from loans
where person_income is NULL; --none

select Count(*)
from loans
where person_home_ownership is NULL; --none

select COUNT(*) from loans
where person_emp_length is NULL; -- 895
-- Could be unemployeed. Can be replaced with 0.

select COUNT(*) from loans
where loan_intent is NULL; -- none

select COUNT(*) from loans
where loan_grade is NULL; -- none

select COUNT(*) from loans
where loan_amnt is NULL; -- none

select COUNT(*) from loans
where loan_int_rate is NULL; -- 3116
/* Could be that the loan was rejected, the offer was abandoned, or it is a new 
application that has not been priced yet.*/
--- investigate nulls
	select * from loans
	where loan_int_rate is NULL; 
	
	select loan_grade,
	COUNT(*)
	from loans
	where loan_int_rate is NULL
	group by loan_grade
	order by loan_grade asc; -- concentrated in low risk levels
	
	select loan_status,
	COUNT(*)
	from loans
	where loan_int_rate is NULL
	group by loan_status
	order by loan_status asc; -- concentrated in non default status
	
	select loan_intent,
	COUNT(*)
	from loans
	where loan_int_rate is NULL
	group by loan_intent
	order by loan_intent asc; -- no apparent pattern
/*These are MNAR as there is a clear pattern. Recomended solution is to impute with the
avgs of each status and risk level.*/

select COUNT(*) from loans
where loan_status is NULL; -- none

select COUNT(*) from loans
where loan_percent_income is NULL; -- none

select COUNT(*) from loans
where cb_person_default_on_file is NULL; -- none

select COUNT(*) from loans
where cb_person_cred_hist_length is NULL; -- none

-- Investigate invalid values
SELECT
MIN(person_age) AS min_age,
MAX(person_age) AS max_age,
ROUND(AVG(person_age)) as avg_age,
MIN(person_income) AS min_income,
MAX(person_income) AS max_income,
ROUND(AVG(person_income),2) as avg_income, -- We seem to have outliers in income (AVG 66074.85 max 6000000)
MIN(person_emp_length) AS min_emp,
MAX(person_emp_length) AS max_emp,
MIN(loan_amnt) AS min_loan,
MAX(loan_amnt) AS max_loan,
MIN(loan_int_rate) AS min_rate,
MAX(loan_int_rate) AS max_rate,
MIN(cb_person_cred_hist_length) AS min_hist,
MAX(cb_person_cred_hist_length) AS max_hist,
MIN(loan_percent_income) AS min_percent,
MAX(loan_percent_income) AS max_percent,
percentile_cont(0.5) WITHIN GROUP (ORDER BY loan_percent_income) AS median_percent
FROM loans;
/*
"min_age"	"max_age"	"avg_age"	"min_income"	"max_income"	"avg_income"	"min_emp"	"max_emp"	"min_loan"	"max_loan"	"min_rate"	"max_rate"	"min_hist"	"max_hist"	"min_percent"	"max_percent"	"median_percent"
20				100			28			4000			6000000			66074.85		0			41			500			35000		5.42		23.22		2			30			0				0.83				0.15
Max age and employment length doesn't make sense. */


-- after fixing invalid and nulls no irregularities
select * from RESULT1
where person_emp_length > person_age;

select * from RESULT1
where person_income < 0;

-- 2. DATA CLEANING
--- 2A. Deal with null values:
--- 1. Employment length
--- Replace NULL with 0 (unemployeed or no record)
UPDATE loans SET person_emp_length = 0 WHERE person_emp_length IS NULL;
SELECT COUNT(*) 
FROM loans
WHERE person_emp_length IS NULL;
-- no more nulls

--- 2. Interest Rate
--- Replace NULL with average values
--- Estimate average values per status and group
SELECT 
loan_grade,
ROUND(AVG(loan_int_rate),2) AS avg_rate
FROM loans
WHERE loan_int_rate IS NOT NULL
GROUP BY loan_grade
ORDER BY loan_grade ASC;
/*
"A"	7.33
"B"	11.00
"C"	13.46
"D"	15.36
"E"	17.01
"F"	18.61
"G"	20.25
*/

UPDATE loans 
SET loan_int_rate = 
CASE 
	WHEN loan_int_rate IS NULL AND loan_grade = 'A' THEN 7.33
	WHEN loan_int_rate IS NULL AND loan_grade = 'B' THEN 11.00
	WHEN loan_int_rate IS NULL AND loan_grade = 'C' THEN 13.46
	WHEN loan_int_rate IS NULL AND loan_grade = 'D' THEN 15.36
	WHEN loan_int_rate IS NULL AND loan_grade = 'E' THEN 17.01
	WHEN loan_int_rate IS NULL AND loan_grade = 'F' THEN 18.61
	WHEN loan_int_rate IS NULL AND loan_grade = 'G' THEN 20.25
	ELSE loan_int_rate
END;

--- sanity check: no null values
SELECT COUNT(*) 
FROM loans
WHERE loan_int_rate is null;

SELECT 
loan_status,
loan_grade,
count(loan_int_rate)
FROM loans
WHERE loan_int_rate IS  NULL
GROUP BY loan_status,loan_grade
ORDER BY loan_grade ASC, loan_status ASC;

-- 2B. Fix invalid values
SELECT *
FROM loans
ORDER BY person_age DESC
LIMIT 10;
-- 144 123 doesn't make sesne with this low employment length. Replace with a more logical value
UPDATE loans SET person_age = 100 WHERE person_age=144 or person_age=123;
SELECT *
FROM loans
ORDER BY person_age DESC
LIMIT 10;-- extreme values replaced with an assumed logical max value.

-- Employment length
SELECT *
FROM loans
ORDER BY person_emp_length DESC
LIMIT 10; -- 123 years of employment doesn't make sense, especially when the person's age is 22 and 21. We will impute with the average of those 2 ages.

SELECT 
person_age,
ROUND(AVG (person_emp_length))
FROM loans
WHERE (person_age =  22 OR person_age = 21) AND person_emp_length <> 123
GROUP BY person_age;
/*
21	3
22	4 */

UPDATE loans SET person_emp_length =
	CASE 
		WHEN person_emp_length = 123 AND person_age = 21 THEN 3
		WHEN person_emp_length = 123 AND person_age = 22 THEN 4
	ELSE person_emp_length
END;

SELECT *
FROM loans
ORDER BY person_emp_length DESC
LIMIT 10; -- imputation successful

-- Income
SELECT *
FROM loans
ORDER BY person_income DESC
LIMIT 20;

--- calculate median
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY person_income) AS median
FROM loans; -- 55000

--- calculate MAD (Median Absolute Deviation)
WITH median_value AS (
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY person_income) AS median
FROM loans
)
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY abs(person_income - median_value.median)) AS mad
FROM loans, median_value; --19360

CREATE TEMP TABLE OUTLIERS2 AS
WITH median_value AS (
    SELECT percentile_cont(0.5) 
           WITHIN GROUP (ORDER BY person_income) AS median
    FROM loans
),
mad_value AS (
    SELECT percentile_cont(0.5) 
           WITHIN GROUP (ORDER BY ABS(person_income - (SELECT median FROM median_value))) AS mad
    FROM loans
)
SELECT l.*
FROM loans l
CROSS JOIN median_value m
CROSS JOIN mad_value d
WHERE ABS(l.person_income - 55000) > 3 * 19360
ORDER BY person_income DESC;

SELECT COUNT(*),
MIN(person_income) AS min_income,
MAX(person_income) AS max_income,
ROUND(AVG(person_income),2) as avg_income
FROM OUTLIERS2; -- we do not have really outliers just high income and low income people. The creation of income brackets can normalise this.

-- Create income, age and employment length brackets
CREATE TEMP TABLE RESULT1 AS
SELECT 
	*,
	CASE
	    WHEN person_income < 50000 THEN 'low'
	    WHEN person_income < 100000 THEN 'mid'
	    WHEN person_income < 200000 THEN 'high'
	    ELSE 'very_high'
	END AS income_groups,
	
	CASE
	    WHEN person_age between 20 and 35 THEN '20 TO 35'
	    WHEN person_age between 36 and 50 THEN '36 TO 50'
	    WHEN person_age between 51 and 65 THEN '51 TO 65'
	    WHEN person_age >= 66 then '66+'
		ELSE 'UNDER 20'
	END AS age_groups,

	CASE
	    WHEN person_emp_length = 0 THEN 'Unemployed / No employment data'
	    WHEN person_emp_length between 1 and 2 THEN 'Entry level'
	    WHEN person_emp_length between 3 and 5 THEN 'Mid level'
		WHEN person_emp_length between 6 and 9 THEN 'Senior level'
	    WHEN person_emp_length > 10 THEN 'Executive'
	END AS employment_groups
FROM loans;

SELECT * FROM RESULT1
LIMIT 10;

select * from RESULT1
where person_emp_length > person_age;

-- create risk level groups
CREATE TEMP TABLE RESULT2 AS
SELECT * ,
	CASE
	    WHEN loan_grade = 'A' THEN 'Low'
		WHEN loan_grade = 'B' OR loan_grade = 'C' THEN 'Moderate'
		WHEN loan_grade = 'D' OR loan_grade = 'E' THEN 'High'
		ELSE 'Highest'
	END AS risk_groups
FROM RESULT1;

SELECT * FROM RESULT2

-- CREATE RISK FLAG WITH 0 AND 1 VALUES WHERE HIGH RISK LOANS ARE: A) HIST DEFAULT, B) D AND BELLOW, C)LTI is no more than 0.3
---DROP TABLE RESULT3;
CREATE TEMP TABLE RESULT3 AS
SELECT * ,
	CASE
	    WHEN cb_person_default_on_file = 'Y' AND risk_groups = 'High' AND loan_percent_income > 0.30 THEN 1
		ELSE 0
	END AS high_risk_flag
FROM RESULT2;

SELECT 
high_risk_flag,
COUNT(*)
FROM RESULT3
GROUP BY high_risk_flag; -- only 360

-- 3. Analysis
--- 3a. portfolio overall
select 
count(*) as total_count,
sum(loan_amnt) as total_sum,
ROUND(avg(loan_amnt),3) AS average
from RESULT3;
-- HIGH COUNT AND SUM BUT LOW AVERAGE WE HAVE MANY LEVELS OF LOANS

--- 3B. PORTFOLIO HEALTH
SELECT 
risk_groups,
COUNT(*)
FROM RESULT3
GROUP BY risk_groups;
/*
"risk_groups"	"count"
"High"			4590
"Highest"		305
"Moderate"		16909
"Low"			10777
*/

SELECT
ROUND(
    100.0 * COUNT(*) / (SELECT COUNT(*) FROM RESULT3),
    2
) AS perc_default
FROM RESULT3
WHERE loan_status = 1; -- 21.82% low number of defaults

--What about those that defaulted in the past as well as now?
SELECT
cb_person_default_on_file,
ROUND(AVG(loan_status)*100,2) AS default_rate
FROM RESULT3
GROUP BY cb_person_default_on_file; -- 37.81%


-- Export file
SELECT * FROM loans;
