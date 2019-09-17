#standardSQL
SELECT
  word,
  SUM(word_count) as wc
FROM
  `bigquery-public-data.samples.shakespeare`
GROUP BY 
   word
ORDER BY
  wc DESC
LIMIT 25
