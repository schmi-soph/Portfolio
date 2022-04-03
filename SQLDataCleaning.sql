/*
Sophie Schmidt
3/27/22
Amazon Web Scraper Data Cleaning and Exploration

SQL Skills used in Data Cleaning section:
Common Table Expressions, 
Windows Functions, 
Pivot/Unpivot, 
Joins, 
Case Statements,
Aliasing,
Dynamic SQL
*/

-- If table exists, drop it
IF object_id('CandleScrapeTable') is not null
	DROP TABLE CandleScrapeData

-- Create New Table
CREATE TABLE CandleScrapeData(
	Username nvarchar(max),
	Stars nvarchar(max),
	Title nvarchar(max),
	LocationDate nvarchar(max),
	Size nvarchar(max),
	Style nvarchar(max),
	Pattern nvarchar(max),
	Verified nvarchar(max),
	Review nvarchar(max),
	Helpful nvarchar(max),
	Abuse nvarchar(max),
	Showing nvarchar(max),
	Zero nvarchar(max),
	Comments nvarchar(max),
	Problem nvarchar(max))

-- Insert CandleScrapeData.csv
BULK INSERT CandleScrapeData
FROM 'C:\Users\Sophie\Desktop\Code\YankeCandleCovid\Data\CandleScrapeData.csv'
WITH(
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	ROWTERMINATOR = '\n'
)

/*
	Note that the next two queries may need to be repeated multiple times.
	The number of times is dependent on the number of titles in each user.
	Example: Someone with "Vine Voice" and "Top 1000 Reviewer" will need
	these queries to be run twice, once for each title.
*/

-- Remove titles such as "Top 1000 Reviewer" from the Stars column
Update CandleScrapeData
SET Stars = NULL
WHERE Stars not like '% out of 5 stars'

-- If there are NULL values in the Stars column shift everything right one column
-- Unpivot the data 
WITH Unpivoted AS
(
	SELECT username, col, scrapedata
	FROM CandleScrapeData
	UNPIVOT
	(
		scrapedata FOR col IN (stars, title, locationdate, size, style, pattern)
	) as unpvt
),
-- Shift the column names when the Stars column is NULL
Cleaned AS
(
	SELECT 
		col_name(object_id('CandleScrapeData'), row_number() OVER 
		(
			PARTITION BY username ORDER BY username
		)+1) [newcol],
		username, col, scrapedata
	FROM Unpivoted
),
-- Pivot the data back to the original position
Pivoted AS
(
	SELECT username, stars, title, locationdate, size, style, pattern
	FROM
	(
		SELECT username, newcol, scrapedata
		FROM Cleaned
	) as clean
	PIVOT
	(
		max(scrapedata) FOR newcol IN (stars, title, locationdate, size, style, pattern)
	) as pvt
)
-- Join CandleScrapeData on Pivoted and update each column
Update CandleScrapeData
SET 
	CandleScrapeData.stars = pvt.stars,
	CandleScrapeData.title = pvt.title,
	CandleScrapeData.locationdate = pvt.locationdate,
	CandleScrapeData.size = pvt.size,
	CandleScrapeData.style = pvt.style,
	CandleScrapeData.pattern = pvt.pattern
FROM 
	CandleScrapeData as csd
	JOIN Pivoted as pvt
		ON csd.Username = pvt.Username

-- Remove "out of 5 stars" from Stars column and cast as int
ALTER TABLE CandleScrapeDATA
ADD rating int

Update CandleScrapeData
SET rating = convert(int, left(stars, 1))

-- Split LocationDate column into seperate values, add new columns and update
ALTER TABLE CandleScrapeData
ADD Location nvarchar(255)
ALTER TABLE CandleScrapeData
ADD Date nvarchar(255)

Update CandleScrapeData
SET Location = substring(LocationDate, 1, charindex(' on', LocationDate))
Update CandleScrapeData
SET Date = substring(LocationDate, charindex('on', LocationDate) + 3, len(LocationDate))

-- Delete Rows not in 'MONTH DAY, YEAR' format
DELETE FROM CandleScrapeData
WHERE DATE not like '%,%'

-- Cast Date as datetime
Update CandleScrapeData
SET Date = cast(date AS date)

-- Remove "Reviewed in" from all elements in Location column
Update CandleScrapeData
SET Location = replace(Location, 'Reviewed in ', '')

-- Remove "the" from the United States and the United Kingdom
Update CandleScrapeData
SET Location = CASE 
	WHEN Location = 'the United States' THEN 'United States'
	WHEN Location = 'the United Kingdom' THEN 'United Kingdom'
	ELSE Location
	END

-- Remove Size:, Style: and Pattern: from respsective columns
Update CandleScrapeData
SET Size = replace(Size, 'Size: ', ''),
	Style = replace(Style, 'Style: ', ''),
	Pattern = replace(Pattern, 'Pattern Name: ', '')

/*
	Note on the following three queries:
	Removing duplicate/unused rows and columns is optional 
	as I understand this would not be done in a production 
	environment. For the sake of this project it should be 
	fine and is mostly here to showcase additional knowledge.
*/

-- Remove Unused Columns
ALTER TABLE CandleScrapeData
DROP COLUMN stars, LocationDate

-- Remove Columns with mostly NULL values
DECLARE @dyn nvarchar(max)
SET @dyn = ''
SELECT @dyn = @dyn + 
	N'IF (SELECT sum(
		CASE
		WHEN ' + col.name + ' is null THEN 1
		ELSE 0
		END) FROM CandleScrapeData) > 
		(SELECT 0.001*count(*)
		FROM CandleScrapeData)
	ALTER TABLE CandleScrapeData
	DROP COLUMN ' + col.name + ' '
FROM sys.columns as col
WHERE col.object_id = object_id('CandleScrapeData')
EXEC sp_executesql @dyn

-- Remove Duplicate rows
WITH RowNumCTE AS 
(
	SELECT *,
		row_number() OVER (
			PARTITION BY username, title, rating, location, date
			ORDER BY username) as RowNum
	FROM CandleScrapeData
)
DELETE FROM RowNumCTE
WHERE RowNum > 1

/*
Data Exploration

SQL skills used in this section:
Subqueries,
Aggragate functions,
WHERE statements (between, like, equal to)
GROUP BY, ORDER BY,
Datetime
*/

-- General Data Exploration
SELECT rating,
	(SELECT round(avg(cast(rating as float)),2)
	FROM CandleScrapeData) as AverageRating,
	count(rating) as NumberOfRatings,
	round(count(rating)/(
		SELECT cast(count(rating) as float) 
		FROM CandleScrapeData 
	)*100, 2) as PercentOfRatings
FROM CandleScrapeData
GROUP BY rating
ORDER BY rating DESC

-- List of Countries by most reviews
SELECT location, count(location) as NumberofReviews, 
	round(avg(cast(rating as float)),2) as AverageRating
FROM CandleScrapeData
GROUP BY location
ORDER BY count(location) DESC

-- List of Countries by most 1 star reviews
SELECT location,
	count(rating) as NumofBadReviews
FROM CandleScrapeData
WHERE rating = 1
GROUP BY location
ORDER BY count(rating) DESC

-- Number of each rating in United States
SELECT rating,
	(SELECT round(avg(cast(rating as float)),2)
	FROM CandleScrapeData 
	WHERE location = 'United States'
	) as AverageRating,
	count(rating) as NumberOfRatings,
	round(count(rating)/(
		SELECT cast(count(rating) as float) 
		FROM CandleScrapeData 
		WHERE location = 'United States'
	)*100, 2) as PercentOfRatings
FROM CandleScrapeData
WHERE location = 'United States'
GROUP by rating
ORDER by rating DESC

-- Number of each rating in North America
SELECT rating,
	(SELECT round(avg(cast(rating as float)),2)
	FROM CandleScrapeData 
	WHERE location IN ('United States', 'Canada', 'Mexico')
	) as AverageRating,
	count(rating) as NumberOfRatings,
	round(count(rating)/(
		SELECT cast(count(rating) as float) 
		FROM CandleScrapeData 
		WHERE location IN ('United States', 'Canada', 'Mexico')
	)*100, 2) as PercentOfRatings
FROM CandleScrapeData
WHERE location IN ('United States', 'Canada', 'Mexico')
GROUP by rating
ORDER by rating DESC

-- Number of each rating in Europe
SELECT rating,
	(SELECT round(avg(cast(rating as float)),2)
	FROM CandleScrapeData
	WHERE location IN ('United Kingdom', 'Germany', 'Italy', 'France', 'Spain')
	) as AverageRating,
	count(rating) as NumberOfRatings,
	round(count(rating)/(
		SELECT cast(count(rating) as float) 
		FROM CandleScrapeData 
		WHERE location IN ('United Kingdom', 'Germany', 'Italy', 'France', 'Spain')
	)*100, 2) as PercentOfRatings
FROM CandleScrapeData
WHERE location IN ('United Kingdom', 'Germany', 'Italy', 'France', 'Spain')
GROUP by rating
ORDER by rating DESC

-- Number of each size of candle
SELECT size, count(size) as NumSize,
	round(avg(cast(rating as float)),2) as AverageRating
FROM CandleScrapeData
GROUP BY size
HAVING count(*) > 1
ORDER BY count(size) DESC

-- Number of each scent
SELECT style, count(style) as NumStyle,
	round(avg(cast(rating as float)),2) as AverageRating
FROM CandleScrapeData
GROUP BY style
HAVING count(*) > 1
ORDER BY count(style) DESC

-- Scents with the most one star reviews
SELECT style, count(rating) as OneStarReviews
FROM CandleScrapeData
WHERE rating = 1
GROUP BY style
ORDER by count(rating) DESC

-- Number of 1 star reviews related to the smell/scent
SELECT count(title) as NoSmellReviews,
	round(count(title)/(
		SELECT cast(count(*) as float) 
		FROM CandleScrapeData 
		WHERE rating = 1
	)*100, 2) as PercentOfBadReviews
FROM CandleScrapeData
WHERE (title LIKE '%smell%' 
OR title LIKE '%scent%')
AND rating = 1

-- Number of 1 star reviews related to shipping issues
SELECT count(title) as MeltedBrokenReviews,
	round(count(title)/(
		SELECT cast(count(*) as float) 
		FROM CandleScrapeData 
		WHERE rating = 1
	)*100, 2) as PercentOfBadReviews
FROM CandleScrapeData
WHERE (title LIKE '%melt%' 
OR title LIKE '%broken%')
AND rating = 1

-- Number of 1 star reviews related to other issues (or issue not listed in title)
SELECT count(title) as OtherBadReviews,
	round(count(title)/(
		SELECT cast(count(*) as float) 
		FROM CandleScrapeData 
		WHERE rating = 1
	)*100, 2) as PercentOfBadReviews
FROM CandleScrapeData
WHERE title NOT LIKE '%smell%' 
AND title NOT LIKE '%scent%'
AND title NOT LIKE '%melted%'
AND title NOT LIKE '%broken%'
AND rating = 1

-- Candle reviews per year since 2020
SELECT year(date) as year, count(year(date)) as ReviewsPerYear,
	round(avg(cast(rating as float)),2) as AverageRatingPerYear
FROM CandleScrapeData
WHERE date > '2020'
GROUP BY year(date)
ORDER BY year(date)

-- 1 Star reviews per month since 2020
SELECT month(date), year(date),
	count(rating) as BadReviewPerMonth
FROM CandleScrapeData
WHERE date > '2020'
AND rating = 1
-- AND location = 'United States'
GROUP BY month(date), year(date)
ORDER BY year(date), month(date)

-- Average reviews per month since 2020
SELECT month(date), year(date),
	round(avg(cast(rating as float)),2) as AverageRatingPerMonth
FROM CandleScrapeData
WHERE date > '2020'
-- AND location = 'United States'
GROUP BY month(date), year(date)
ORDER BY year(date), month(date)

-- Candle reviews in first quarter (to compare to 2022 so far)
SELECT year(date) as year, count(year(date)) as ReviewsPerYear,
	round(avg(cast(rating as float)),2) as AverageRatingPerYear
FROM CandleScrapeData
WHERE date > '2020'
AND month(date) BETWEEN 1 AND 3
GROUP BY year(date)
ORDER BY year(date)

-- Candle reviews per month in 2020
SELECT month(date) as month, 
	count(month(date)) as ReviewsPerMonth,
		round(count(month(date))/(
		SELECT cast(count(*) as float) 
		FROM CandleScrapeData 
		WHERE date BETWEEN '2020' AND '2021'
	)*100, 2) as PercentOf2020Reviews
FROM CandleScrapeData
WHERE date BETWEEN '2020' AND '2021'
GROUP BY month(date)
ORDER BY month(date)

-- Candle reviews per month in 2021
SELECT month(date) as month, 
	count(month(date)) as ReviewsPerMonth,
	round(count(month(date))/(
		SELECT cast(count(*) as float) 
		FROM CandleScrapeData 
		WHERE date BETWEEN '2021' AND '2022'
	)*100, 2) as PercentOf2021Reviews
FROM CandleScrapeData
WHERE date BETWEEN '2021' AND '2022'
GROUP BY month(date)
ORDER BY month(date)

-- Candle reviews per month in 2022 (so far)
SELECT month(date) as month, 
	count(month(date)) as ReviewsPerMonth,
	round(count(month(date))/(
		SELECT cast(count(*) as float) 
		FROM CandleScrapeData 
		WHERE date > '2022'
	)*100, 2) as PercentOf2022Reviews
FROM CandleScrapeData
WHERE date > '2022'
GROUP BY month(date)
ORDER BY month(date)

-- One star reviews per month in 2020
SELECT month(date) as month, 
	count(month(date)) as BadReviewsPerMonth
FROM CandleScrapeData
WHERE date BETWEEN '2020' AND '2021'
AND rating = 1
GROUP BY month(date)
ORDER BY month(date)

-- One star reviews per month in 2021
SELECT month(date) as month, 
	count(month(date)) as BadReviewsPerMonth
FROM CandleScrapeData
WHERE date BETWEEN '2021' AND '2022'
AND rating = 1
GROUP BY month(date)
ORDER BY month(date)

-- One star reviews per month in 2020 (so far)
SELECT month(date) as month, 
	count(month(date)) as BadReviewsPerMonth
FROM CandleScrapeData
WHERE date > '2022'
AND rating = 1
GROUP BY month(date)
ORDER BY month(date)