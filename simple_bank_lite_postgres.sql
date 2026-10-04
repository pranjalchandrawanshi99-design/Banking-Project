/* SIMPLE BANK (LITE VERSION) - PostgreSQL
   4 tables, easy queries, one safe money transfer.
   Run the whole script once, then run queries one by one. */

-- Everything lives in its own schema, so it won't touch your other data.
DROP SCHEMA IF EXISTS simple_bank CASCADE;
CREATE SCHEMA simple_bank;
SET search_path TO simple_bank;

-- ========== PART 1: TABLES ==========
CREATE TABLE customers (
    customer_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  -- auto-numbered unique ID
    name        VARCHAR(100) NOT NULL,
    city        VARCHAR(50)  NOT NULL,
    phone       CHAR(10)     NOT NULL UNIQUE                   -- no two customers share a phone
);

CREATE TABLE accounts (
    account_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id  INT NOT NULL REFERENCES customers(customer_id),   -- must belong to a real customer
    account_type VARCHAR(10) NOT NULL CHECK (account_type IN ('SAVINGS','CURRENT')),
    balance      NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (balance >= 0)  -- no negative balance
);

CREATE TABLE transactions (
    txn_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id INT NOT NULL REFERENCES accounts(account_id),
    txn_type   VARCHAR(10) NOT NULL CHECK (txn_type IN ('DEPOSIT','WITHDRAWAL')),
    amount     NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    txn_date   DATE NOT NULL
);

CREATE TABLE loans (
    loan_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id INT NOT NULL REFERENCES customers(customer_id),
    amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    status      VARCHAR(10) NOT NULL CHECK (status IN ('ACTIVE','CLOSED','DEFAULTED'))
);

-- ========== PART 2: SAMPLE DATA (fictional) ==========
INSERT INTO customers (name, city, phone) VALUES
('Rohan Mehta',   'Mumbai',    '9000000001'),
('Ananya Iyer',   'Chennai',   '9000000002'),
('Karan Malhotra','Delhi',     '9000000003'),
('Priya Nair',    'Bengaluru', '9000000004'),
('Vikram Singh',  'Delhi',     '9000000005'),
('Sneha Kulkarni','Pune',      '9000000006'),
('Arjun Reddy',   'Bengaluru', '9000000007'),
('Meera Joshi',   'Mumbai',    '9000000008');

INSERT INTO accounts (customer_id, account_type, balance) VALUES
(1,'SAVINGS',  45000),   -- account 1
(2,'SAVINGS',  82000),   -- 2
(3,'SAVINGS',  15000),   -- 3
(4,'SAVINGS', 230000),   -- 4
(5,'CURRENT', 540000),   -- 5
(6,'SAVINGS',  67000),   -- 6
(7,'SAVINGS', 125000),   -- 7
(8,'SAVINGS',  38000),   -- 8 (Meera never transacts)
(1,'CURRENT', 260000),   -- 9 (Rohan has 2 accounts)
(3,'SAVINGS',   8000);   -- 10 (Karan has 2 accounts)

INSERT INTO transactions (account_id, txn_type, amount, txn_date) VALUES
(1,'DEPOSIT', 20000,'2026-07-02'), (1,'WITHDRAWAL', 5000,'2026-07-10'),
(2,'DEPOSIT', 30000,'2026-07-05'), (2,'WITHDRAWAL', 7000,'2026-08-01'),
(3,'DEPOSIT', 15000,'2026-07-08'), (3,'WITHDRAWAL', 2000,'2026-08-03'),
(4,'DEPOSIT', 50000,'2026-08-05'), (4,'WITHDRAWAL',10000,'2026-08-20'),
(5,'DEPOSIT',250000,'2026-08-09'), (5,'WITHDRAWAL',100000,'2026-09-01'),
(6,'DEPOSIT', 40000,'2026-09-02'), (7,'DEPOSIT', 60000,'2026-09-03'),
(7,'WITHDRAWAL',20000,'2026-09-12'), (9,'DEPOSIT', 12000,'2026-09-05'),
(10,'DEPOSIT', 8000,'2026-09-06');

INSERT INTO loans (customer_id, amount, status) VALUES
(1,4000000,'ACTIVE'), (4,500000,'ACTIVE'), (5,2000000,'ACTIVE'), (3,200000,'DEFAULTED');

-- ========== PART 3: QUERIES (run one at a time) ==========

-- Q1. See all customers
SELECT * FROM customers;

-- Q2. Customers in Delhi
SELECT name, city FROM customers WHERE city = 'Delhi';

-- Q3. Accounts with balance above 1,00,000, highest first
SELECT account_id, balance FROM accounts WHERE balance > 100000 ORDER BY balance DESC;

-- Q4. Total money in the bank, average balance, number of accounts
SELECT SUM(balance) AS total_money, ROUND(AVG(balance), 2) AS avg_balance, COUNT(*) AS num_accounts FROM accounts;

-- Q5. Total deposits vs withdrawals
SELECT txn_type, SUM(amount) AS total, COUNT(*) AS num_txns FROM transactions GROUP BY txn_type;

-- Q6. Each customer's name with their accounts (INNER JOIN)
SELECT c.name, a.account_id, a.account_type, a.balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id;

-- Q7. Total balance per customer, top 3 (JOIN + GROUP BY)
SELECT c.name, SUM(a.balance) AS total_balance
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.name
ORDER BY total_balance DESC
LIMIT 3;

-- Q8. Customers with more than one account (GROUP BY + HAVING)
SELECT c.name, COUNT(*) AS num_accounts
FROM customers c
JOIN accounts a ON a.customer_id = c.customer_id
GROUP BY c.customer_id, c.name
HAVING COUNT(*) > 1;

-- Q9. Customers who NEVER made a transaction (LEFT JOIN + IS NULL)
SELECT DISTINCT c.name
FROM customers c
LEFT JOIN accounts a     ON a.customer_id = c.customer_id
LEFT JOIN transactions t ON t.account_id  = a.account_id
WHERE t.txn_id IS NULL;

-- Q10. Customers with loans and the loan status
SELECT c.name, l.amount, l.status
FROM customers c
JOIN loans l ON l.customer_id = c.customer_id;

-- Q11. Total loan amount per city
SELECT c.city, SUM(l.amount) AS total_loans
FROM customers c
JOIN loans l ON l.customer_id = c.customer_id
GROUP BY c.city;

-- ========== PART 4: SAFE MONEY TRANSFER (transaction) ==========
-- Rohan (account 1) sends Rs 10,000 to Ananya (account 2).
-- Both updates must happen together or not at all.
-- Select ALL lines from BEGIN to COMMIT and run them together.

BEGIN;
UPDATE accounts SET balance = balance - 10000 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 10000 WHERE account_id = 2;
COMMIT;

SELECT account_id, balance FROM accounts WHERE account_id IN (1,2);   -- 1 is down 10000, 2 is up 10000

-- Now see ROLLBACK (the undo button):
BEGIN;
UPDATE accounts SET balance = balance - 10000 WHERE account_id = 1;
ROLLBACK;
SELECT account_id, balance FROM accounts WHERE account_id = 1;        -- unchanged

-- Constraint test: this FAILS because balance cannot go below zero
-- UPDATE accounts SET balance = balance - 99999999 WHERE account_id = 1;
