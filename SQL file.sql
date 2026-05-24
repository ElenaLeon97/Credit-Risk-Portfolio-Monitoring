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
cb_person_default_on_file	Historical default
cb_preson_cred_hist_length	Credit history length
*/ 
-- DELETE FROM loans;
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

-- Data Cleaning
-- Deal with null values:
-- 1. Employment length
-- Replace NULL with 0 (unemployeed or no record)
UPDATE loans SET person_emp_length = 0 WHERE person_emp_length IS NULL;
SELECT COUNT(*) 
FROM loans
WHERE person_emp_length IS NULL;
-- no more nulls

-- 2. Interest Rate
-- Replace NULL with average values
-- Estimate average values per status and group
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

-- sanity check: no null values
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

-- Export file
SELECT * FROM loans;