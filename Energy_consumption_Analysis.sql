CREATE DATABASE EnergyDb2;
USE EnergyDb2;

-- 1. Country Table
CREATE TABLE country(
    country VARCHAR(100) UNIQUE,
    c_id VARCHAR(10) PRIMARY KEY
);

-- 2. emission_3 table
CREATE TABLE emission_3 (
    country VARCHAR(100),
    energy_type VARCHAR(50),
    year INT,
    emission INT,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(Country)
);

-- 3. Population Table
CREATE TABLE population (
    countries VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (countries) REFERENCES country(country)
);

-- 4. production table
CREATE TABLE production (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    production INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

-- 5. GPD_3 table
CREATE TABLE gdp_3 (
    Country VARCHAR(100),
    year INT,
    Value DOUBLE,
    FOREIGN KEY (Country) REFERENCES country(Country)
);

-- 6. consumption table
CREATE TABLE consumption (
    country VARCHAR(100),
    energy VARCHAR(50),
    year INT,
    consumption INT,
    FOREIGN KEY (country) REFERENCES country(Country)
);

SELECT COUNT(*) AS country_count FROM country;
SELECT COUNT(*) AS emission_count FROM emission_3;
SELECT COUNT(*) AS population_count FROM population;
SELECT COUNT(*) AS production_count FROM production;
SELECT COUNT(*) AS gdp_count FROM gdp_3;
SELECT COUNT(*) AS consumption_count FROM consumption;


SELECT count(DISTINCT(country)) FROM country;

SELECT * FROM country LIMIT 10;
SELECT * FROM emission_3 LIMIT 10;
SELECT * FROM population LIMIT 10;
SELECT * FROM production LIMIT 10;
SELECT * FROM gdp_3 LIMIT 10;
SELECT * FROM consumption LIMIT 10;

-- DATA ANALYSIS QUESTIONS:

-- General & Comparative Analysis:
-- 1. What is the total emission per country for the most recent years available?
SELECT 
    country, 
    SUM(emission) AS total_emission
FROM emission_3
WHERE year = (SELECT MAX(year) FROM emission_3)
GROUP BY country
ORDER BY total_emission DESC;

-- 2. What are the top 5 Countires by GDP in the most recent years?
SELECT 
	country, 
    Value AS GDP,
    year
FROM 
gdp_3
WHERE year= (SELECT MAX(year) FROM gdp_3)
ORDER BY GDP DESC
LIMIT 5;
    
-- Compare energy production and consumption by country and year.
-- 1. Which energy types contributes most to emissions across all countries?
SELECT 
    energy_type,
    SUM(emission) AS total_emission
FROM emission_3
GROUP BY energy_type
ORDER BY total_emission DESC;

-- 2. How have global emissions changed year over year?
SELECT 
	year,
    SUM(emission) AS total_global_emission,
    LEAD(SUM(emission)) OVER (ORDER BY year) - SUM(emission)  AS emission_change_compared_to_next_year
FROM emission_3
GROUP BY year
ORDER BY year;

-- 3. what is the trend in GDP for each country over the given years?
SELECT 
	country,
    value AS current_gdp,
    LAG(value) OVER (PARTITION BY country ORDER BY year) AS previous_gdp,
	(value - LAG(value) OVER (PARTITION BY country ORDER BY year))
FROM gdp_3
ORDER BY country, year;

-- 4. How has population growth affected total_emissions in each country?
SELECT
	p.countries AS country,
    p.year,
    p.value AS population,
    e.total_emission
FROM population p
JOIN(
	SELECT 
		country,
        year,
        SUM(emission) AS total_emission
	FROM emission_3 
    GROUP BY country, year
) e 
ON p.countries = e.country AND p.year = e.year
ORDER BY country, year;

-- 5. Has energy consumption increased or decreased over the year for major economies?
SELECT 
	country,
	year,
    SUM(consumption) AS total_consumption,
    SUM(consumption) - LAG(SUM(consumption)) OVER (PARTITION BY country ORDER BY year) AS change_from_prev_year
FROM consumption
GROUP BY country, year
ORDER BY country, year;
	
-- 6. What is the average yearly change in emissions per capita for each country?
WITH EmissionPerCapita AS (
    SELECT 
        country,
        year,
        AVG(per_capita_emission) AS avg_per_capita
    FROM emission_3
    GROUP BY country, year
),
YearlyChanges AS (
    SELECT 
        country,
        year,
        avg_per_capita,
        avg_per_capita - LAG(avg_per_capita) OVER (PARTITION BY country ORDER BY year) AS yearly_change
    FROM EmissionPerCapita
)
SELECT 
    country,
    ROUND(AVG(yearly_change)) AS avg_yearly_change
FROM YearlyChanges
WHERE yearly_change IS NOT NULL
GROUP BY country
ORDER BY avg_yearly_change DESC;

-- Ratio & Per Capita Analysis
-- 1. What is the emission-to-GDP ratio for each country by year.
SELECT 
	e.country,
    e.year,
    e.total_emission,
    g.value AS GDP,
    ROUND(e.total_emission/g.value, 4) AS emission_to_gdg_ratio
    FROM (
	SELECT country, year, SUM(emission) AS total_emission
    FROM emission_3
    GROUP BY country, year
) e
JOIN gdp_3 g
ON e.country = g.country AND e.year = g.year
ORDER BY e.country, e.year;

-- 2. What is the energy consumption per capita for each country over the last decade
SELECT 	
	c.country,
    c.year,
    c.total_consumption,
    p.value AS population,
    ROUND(c.total_consumption/p.value,6) AS consumption_per_capita
	FROM(
		SELECT
			country,
            year,
            SUM(consumption) AS total_consumption
		FROM consumption
        GROUP BY country, year
) c 
JOIN population p
ON c.country = p.countries AND c.year = p.year
WHERE c.year>= YEAR(curdate())-10
ORDER BY c.country, c.year;

-- 3. How does energy production per capita vary across countries
SELECT	
	p.country,
    p.year,
    p.total_production,
    pop.value AS population,
    ROUND(p.total_production/pop.value) AS production_per_capita
FROM ( 
	SELECT
		country,
        year,
        SUM(production) AS total_production
	FROM production
    GROUP BY country, year
) p
JOIN population pop
ON p.country = pop.countries AND p.year = pop.year
ORDER BY production_per_capita DESC;

-- 4. Which countries have the highest energy consumption relative to GDP?
SELECT 
	c.country AS country,
    ROUND(SUM(cs.consumption)/SUM(g.value), 6) AS energy_to_gdp_ratio,
    ROUND(SUM(cs.consumption),2) AS total_consumption,
    ROUND(SUM(g.value), 2) AS total_gdp
FROM consumption cs
JOIN gdp_3 g
	ON cs.country = g.country AND cs.year = g.year
JOIN country c
	ON c.country = cs.country
WHERE g.value > 0
GROUP BY c.country 
ORDER BY energy_to_gdp_ratio DESC
LIMIT 10;


-- Global Comparisons:
-- 1. What are the top 10 countries by population and how do their emissions compare?
WITH Latest_pop AS (
	SELECT 
		countries AS country,
        year,
        value AS population
	FROM population
    WHERE year = (SELECT MAX(year) FROM population)
),
top_10 AS(
SELECT 
	country,
    population,
    year
FROM Latest_pop
ORDER BY population DESC
LIMIT 10
)
SELECT 
	t.country,
    t.population, 
    t.year,
	e.emission,
    e.per_capita_emission
FROM top_10 t
JOIN emission_3 e
	ON t.country = e.country
    AND e.year = (SELECT MAX(year) FROM emission_3)
ORDER BY t.population DESC;

-- 2. Which countries have improved (reduced) their per capita emissions the most over the last decade.
WITH year_limits AS(
SELECT 
	MAX(year) AS max_year,
    MIN(year) AS min_year
FROM emission_3
WHERE year >= (SELECT MAX(year) - 10 FROM emission_3)
),
emission_change AS(
	SELECT 
		e.country,
        MAX(CASE WHEN e.year = (SELECT max_year FROM year_limits) THEN e.per_capita_emission END) AS latest_emission,
        MAX(CASE WHEN e.year = (SELECT min_year FROM year_limits) THEN e.per_capita_emission END) AS earliest_emission
	FROM emission_3 e
    GROUP BY e.country
)
SELECT 
	country,
    earliest_emission,
    latest_emission,
    ROUND(earliest_emission - latest_emission) AS reduction_in_emission
FROM emission_change 
ORDER BY reduction_in_emission DESC
LIMIT 10;

-- What is the global share (%) of emissions by country
WITH latest_year AS (
    SELECT MAX(year) AS max_year FROM emission_3
),
country_emissions AS (
    SELECT 
        e.country,
        SUM(e.emission) AS total_emission
    FROM emission_3 e
    JOIN latest_year l ON e.year = l.max_year
    GROUP BY e.country
),
global_total AS (
    SELECT SUM(total_emission) AS world_total FROM country_emissions
)
SELECT 
    c.country,
    ROUND(c.total_emission, 2) AS total_emission,
    ROUND((c.total_emission / g.world_total) * 100, 2) AS global_share_percent
FROM country_emissions c
CROSS JOIN global_total g
ORDER BY global_share_percent DESC
LIMIT 10;

-- What is the global average,gdp,emission and population by year.
WITH gdp_yearly AS (
    SELECT year, AVG(Value) AS avg_gdp
    FROM gdp_3
    GROUP BY year
),
emission_yearly AS (
    SELECT year, AVG(emission) AS avg_emission
    FROM emission_3
    GROUP BY year
),
population_yearly AS (
    SELECT year, AVG(Value) AS avg_population
    FROM population
    GROUP BY year
)
SELECT 
    g.year,
    ROUND(g.avg_gdp, 2) AS avg_gdp,
    ROUND(e.avg_emission, 2) AS avg_emission,
    ROUND(p.avg_population, 2) AS avg_population
FROM gdp_yearly g
LEFT JOIN emission_yearly e ON g.year = e.year
LEFT JOIN population_yearly p ON g.year = p.year
ORDER BY g.year;


