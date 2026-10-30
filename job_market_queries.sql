-- Operation Get Employed — Portfolio Project 2
-- Job postings + skills analysis (Data Analyst / Data Scientist / Data Engineer)
-- Run against job_market.db after importing job_postings.csv and job_skills_long.csv
-- Safe to run top to bottom, repeatedly.

-- (Step 0, the column-rename fix for job_skills_long, already ran
-- successfully in an earlier pass and has been removed from this file.
-- DB Browser stops at the first error in a script rather than skipping
-- past it, so leaving already-applied one-time fixes in here would
-- just block everything below them on every rerun.)


-- ============================================================
-- STEP 1: Filter job_postings down to our three target roles
-- ============================================================
-- search_position in the raw data doesn't line up with the actual job,
-- so we filter on job_title instead. This is a simple substring match,
-- which means it'll miss some real data roles with unusual titles
-- (e.g. "Data/Process Analyst", "ETL Data Warehouse Specialist") and
-- that's a known, intentional tradeoff, not a bug. "data science" is
-- included alongside "data scientist" because titles like "Senior
-- Manager, Data Science" and "AI Data Science Lead" use the noun
-- form instead of the person-title form.

DROP VIEW IF EXISTS target_postings;

CREATE VIEW target_postings AS
SELECT *
FROM job_postings
WHERE LOWER(job_title) LIKE '%data analyst%'
   OR LOWER(job_title) LIKE '%data scientist%'
   OR LOWER(job_title) LIKE '%data science%'
   OR LOWER(job_title) LIKE '%data engineer%';

-- Sanity check: how many postings matched, and what do the titles look like?
SELECT COUNT(*) AS matched_postings FROM target_postings;

SELECT job_title, COUNT(*) AS n
FROM target_postings
GROUP BY job_title
ORDER BY n DESC
LIMIT 30;

-- Sanity check: what "data"-adjacent titles got left out? Worth a skim
-- to confirm nothing important is being excluded by mistake.
SELECT DISTINCT job_title
FROM job_postings
WHERE LOWER(job_title) LIKE '%data%'
  AND job_title NOT IN (SELECT job_title FROM target_postings)
ORDER BY job_title
LIMIT 50;


-- ============================================================
-- STEP 2: Normalize skill names for the target postings
-- ============================================================
-- Same idea as the typo lookup from Project 1: the raw skill labels
-- aren't perfectly clean, so wording variants of the same skill get
-- collapsed into one name here, in a single place, instead of
-- repeating the same CASE WHEN logic in every query below.
-- "communication" and "communication skills" were the first pair
-- found this way — add more lines here if later results surface
-- other duplicates (e.g. "ml" vs "machine learning").
--
-- remote_flag is added here too, instead of using job_type. job_type
-- turned out to be almost useless for this (4,658 Onsite vs 1 Remote
-- and 1 Hybrid), so remote status is detected instead by looking for
-- the word "remote" in job_title or job_location. That catches 44 of
-- the 4,660 matched postings — small, so Question 4's results below
-- should be read as a directional look, not a confident finding.

DROP VIEW IF EXISTS target_skills_clean;

CREATE VIEW target_skills_clean AS
SELECT
    s.job_link,
    CASE
        WHEN LOWER(t.job_title) LIKE '%remote%' OR LOWER(t.job_location) LIKE '%remote%'
            THEN 'Remote'
        ELSE 'Not flagged remote'
    END AS remote_flag,
    CASE
        WHEN LOWER(TRIM(s.job_skills)) = 'communication skills' THEN 'communication'
        ELSE LOWER(TRIM(s.job_skills))
    END AS skill
FROM job_skills_long s
JOIN target_postings t ON s.job_link = t.job_link;


-- ============================================================
-- QUESTION 1: What skills are most in demand across these roles?
-- ============================================================
SELECT
    skill,
    COUNT(DISTINCT job_link) AS postings_count,
    ROUND(
        COUNT(DISTINCT job_link) * 100.0 / (SELECT COUNT(*) FROM target_postings),
        1
    ) AS pct_of_postings
FROM target_skills_clean
GROUP BY skill
ORDER BY postings_count DESC
LIMIT 25;


-- ============================================================
-- QUESTION 3: Which skills tend to show up together?
-- ============================================================
-- Self-join on job_link, keeping only pairs where skill_a < skill_b
-- alphabetically so each pair is counted once, not twice (and a skill
-- never pairs with itself).

SELECT
    a.skill AS skill_a,
    b.skill AS skill_b,
    COUNT(*) AS postings_together
FROM (SELECT DISTINCT job_link, skill FROM target_skills_clean) a
JOIN (SELECT DISTINCT job_link, skill FROM target_skills_clean) b
  ON a.job_link = b.job_link
 AND a.skill < b.skill
GROUP BY a.skill, b.skill
ORDER BY postings_together DESC
LIMIT 25;


-- ============================================================
-- QUESTION 4: Do remote and on-site postings ask for different skills?
-- ============================================================
-- Based on remote_flag (see note in Step 2), not job_type.

SELECT remote_flag, COUNT(DISTINCT job_link) AS n
FROM target_skills_clean
GROUP BY remote_flag;

-- Top 15 skills within each group, side by side via a window function.
WITH skill_counts AS (
    SELECT
        remote_flag,
        skill,
        COUNT(DISTINCT job_link) AS postings_count
    FROM target_skills_clean
    GROUP BY remote_flag, skill
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY remote_flag ORDER BY postings_count DESC) AS rnk
    FROM skill_counts
)
SELECT remote_flag, skill, postings_count
FROM ranked
WHERE rnk <= 15
ORDER BY remote_flag, rnk;


-- ============================================================
-- QUESTION 2: Franklyn's own skillset vs market demand
-- ============================================================
-- Skill names here are typed to match the normalized labels in
-- target_skills_clean (lowercase, same wording the data uses).

WITH my_skills(skill) AS (
    VALUES ('sql'), ('python'), ('power bi'), ('excel'), ('tableau'), ('communication'), ('data analysis'), ('data visualization')
)

-- How each of Franklyn's skills actually performs in the demand data.
SELECT
    m.skill,
    COALESCE(d.postings_count, 0) AS postings_count,
    ROUND(COALESCE(d.postings_count, 0) * 100.0 / (SELECT COUNT(*) FROM target_postings), 1) AS pct_of_postings
FROM my_skills m
LEFT JOIN (
    SELECT skill, COUNT(DISTINCT job_link) AS postings_count
    FROM target_skills_clean
    GROUP BY skill
) d ON d.skill = m.skill
ORDER BY postings_count DESC;

-- The top in-demand skills Franklyn doesn't have yet — the actual gap list.
WITH my_skills(skill) AS (
    VALUES ('sql'), ('python'), ('power bi'), ('excel'), ('tableau'), ('communication'), ('data analysis'), ('data visualization')
)
SELECT
    skill,
    COUNT(DISTINCT job_link) AS postings_count,
    ROUND(COUNT(DISTINCT job_link) * 100.0 / (SELECT COUNT(*) FROM target_postings), 1) AS pct_of_postings
FROM target_skills_clean
WHERE skill NOT IN (SELECT skill FROM my_skills)
GROUP BY skill
ORDER BY postings_count DESC
LIMIT 15;
