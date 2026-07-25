USE sentiment_p;
select * from flipkart;

SET SQL_SAFE_UPDATES = 0;
SET SQL_SAFE_UPDATES = 1;


-- Remove all '?' characters from product_name
UPDATE flipkart
SET product_name = REPLACE(product_name, '?', '')
WHERE product_name LIKE '%?%';

-- Decode common HTML entities in product_name (extend as needed)
UPDATE flipkart
SET product_name = REPLACE(product_name, '&amp;', '&')
WHERE product_name LIKE '%&amp;%';

UPDATE flipkart
SET product_name = REPLACE(product_name, '&nbsp;', ' ')
WHERE product_name LIKE '%&nbsp;%';

UPDATE flipkart
SET product_name = REPLACE(product_name, '&quot;', '"')
WHERE product_name LIKE '%&quot;%';

UPDATE flipkart
SET product_name = REPLACE(product_name, '&#39;', '''')
WHERE product_name LIKE '%&#39;%';

-- Optional: remove stray non-alphanumeric symbols except common punctuation
UPDATE flipkart
SET product_name = REGEXP_REPLACE(product_name, '[^a-zA-Z0-9 ,()/_-]', '')
WHERE product_name REGEXP '[^a-zA-Z0-9 ,()/_-]';

-- Strip currency symbols (₹, Rs.), commas, spaces; cast to decimal
UPDATE flipkart
SET product_price = NULLIF(REGEXP_REPLACE(product_price, '[^0-9\\.]', ''), '') + 0.0
WHERE product_price IS NOT NULL;



-- Ensure sentiment values are canonical (positive/negative/neutral)
UPDATE flipkart
SET Sentiment = CASE LOWER(TRIM(Sentiment))
  WHEN 'positive' THEN 'positive'
  WHEN 'negative' THEN 'negative'
  WHEN 'neutral'  THEN 'neutral'
  WHEN 'pos' THEN 'positive'
  WHEN 'neg' THEN 'negative'
  WHEN 'neu' THEN 'neutral'
  ELSE Sentiment
END;

-- Optional: ensure Rate within 1–5; flag anomalies
SELECT COUNT(*) AS bad_rate_rows
FROM flipkart
WHERE Rate NOT BETWEEN 1 AND 5 OR Rate IS NULL;


-- View: attach price_band using cumulative distribution over product_price_num
-- DROP VIEW IF EXISTS vw_reviews_banded;
CREATE VIEW vw_reviews_banded AS
SELECT
  *,
  CASE
    WHEN product_price IS NULL THEN 'Unknown'
    WHEN CUME_DIST() OVER (ORDER BY product_price) <= 0.3333 THEN 'Low'
    WHEN CUME_DIST() OVER (ORDER BY product_price) <= 0.6667 THEN 'Mid'
    ELSE 'High'
  END AS price_band
FROM flipkart;

-- View: attach rating buckets
CREATE VIEW vw_reviews_bucketed AS
SELECT
  *,
  CASE
    WHEN Rate BETWEEN 1 AND 2 THEN 'Low (1–2)'
    WHEN Rate = 3 THEN 'Mid (3)'
    WHEN Rate BETWEEN 4 AND 5 THEN 'High (4–5)'
    ELSE 'Unknown'
  END AS rate_bucket
FROM flipkart;


-- 5.1 Overall sentiment distribution (counts and %)
SELECT
  Sentiment,
  COUNT(*) AS review_count,
  ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM flipkart), 0), 2) AS pct
FROM flipkart
GROUP BY Sentiment
ORDER BY Sentiment;

-- 5.2 Sentiment by product (Top N)
SELECT
  product_name,
  Sentiment,
  COUNT(*) AS review_count
FROM flipkart
GROUP BY product_name, Sentiment
ORDER BY review_count DESC
LIMIT 50;

-- 5.3 Average star rating by sentiment
SELECT
  Sentiment,
  ROUND(AVG(Rate), 2) AS avg_rate,
  COUNT(*) AS n
FROM flipkart
GROUP BY Sentiment
ORDER BY Sentiment;

-- 5.4 Median price by sentiment (window-based median)
WITH ordered AS (
  SELECT
    Sentiment,
    product_price,
    ROW_NUMBER() OVER (PARTITION BY Sentiment ORDER BY product_price) AS rn,
    COUNT(*)     OVER (PARTITION BY Sentiment) AS cnt
  FROM flipkart
  WHERE product_price IS NOT NULL
)
SELECT
  Sentiment,
  AVG(product_price) AS median_price
FROM ordered
WHERE
  (cnt % 2 = 1 AND rn = (cnt + 1) / 2)     -- odd: middle value
   OR
  (cnt % 2 = 0 AND rn IN (cnt/2, cnt/2 + 1))  -- even: average of two middles
GROUP BY Sentiment
ORDER BY Sentiment;

-- 5.5 Top products by negative reviews
SELECT
  product_name,
  COUNT(*) AS negative_count
FROM flipkart
WHERE Sentiment = 'negative'
GROUP BY product_name
ORDER BY negative_count DESC
LIMIT 20;

-- 5.6 Sentiment by price band & rating bucket
SELECT price_band, Sentiment, COUNT(*) AS n
FROM vw_reviews_banded
GROUP BY price_band, Sentiment
ORDER BY price_band, Sentiment;

SELECT rate_bucket, Sentiment, COUNT(*) AS n
FROM vw_reviews_bucketed
GROUP BY rate_bucket, Sentiment
ORDER BY rate_bucket, Sentiment;


SELECT * FROM flipkart LIMIT 5;


