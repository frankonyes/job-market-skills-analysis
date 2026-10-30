# What Data Jobs Actually Ask For (and Where I Stand Against That)

I wanted to answer a question that matters to me directly: out of everything a Data Analyst, Data Scientist, or Data Engineer posting might ask for, what actually comes up the most, and how do my current skills measure up against that? I used a dataset of real LinkedIn job postings and their listed skills to find out, and the process of getting a clean answer turned out to be its own small education in data cleaning.

## Summary

Python and SQL are, by a wide margin, the two most requested skills across these roles, each showing up in roughly six out of every ten postings. I already have both, along with data analysis and data visualization, the third and fourth most requested skills, so I cover four of the top five. My biggest gaps are machine learning and R, which matter more if I ever lean toward the Data Scientist side rather than Analyst. I also looked at which skills tend to travel together, and tried to compare remote versus on-site postings, though that last one came with a real limitation I'll get into below.

## Interactive dashboard

I built the results into a Tableau Public dashboard so the findings are easy to scan: [View the dashboard on Tableau Public](https://public.tableau.com/views/topskills_17932807889830/DataJobMarket). It has four charts: the most requested skills (my skills in orange, gaps in blue), my own skills against market demand, the skill pairs that show up together most, and remote versus on-site postings side by side. Three headline numbers sit across the top so the main story is clear in a few seconds.

## Questions I set out to answer

1. What skills show up most often across Data Analyst, Data Scientist, and Data Engineer postings?
2. How does my own current skillset compare to that demand?
3. Which skills tend to appear together in the same posting?
4. Do remote postings ask for different skills than on-site ones?

## Key findings

**Top skills overall.** Python appears in 62.3% of matched postings, SQL in 60.8%. After that it drops off: data analysis (40.0%), data visualization (34.1%), machine learning (30.6%), data science (25.0%), tableau (24.4%), and R (23.9%). Python and SQL aren't just individually common, they're the single most common pair too, showing up together in 2,150 postings, more than double any other pairing.

**Me against the market.** Of my current skills, python (62.3%) and sql (60.8%) line up with the two most in-demand skills there are, data analysis (40.0%) is third, and data visualization (34.1%) is fourth. Communication sits at 34.6%, tableau at 24.4%. Power BI (13.6%) and Excel (8.7%) are useful but further down the list than I expected. The clearest gaps are machine learning (30.6%) and R (23.9%), but they lean toward Data Scientist postings specifically, so how much they matter depends on which of the three roles I end up chasing hardest.

**Skills that travel together.** Beyond the python/sql pair, two loose clusters show up. One centers on python with r, spark, java, and aws, which reads like the engineering and machine learning side of these roles. The other centers on sql with tableau, data visualization, and communication, which reads like the reporting and business-facing side. Worth knowing which cluster a given posting leans toward before assuming "data skills" means one fixed thing.

**Remote versus on-site.** This one didn't work the way I expected. The field meant to capture this, job_type, turned out to be almost useless: 4,658 postings were labeled Onsite against exactly 1 Remote and 1 Hybrid. I built a workaround by searching job_title and job_location for the word "remote" instead, which caught 44 postings, a usable but small sample. Python and SQL still led even in that smaller group, which I'd call a real signal. But several of the next skills down the list, things like CDISC, FHIR, and OMOP, are healthcare and clinical-data standards, which tells me this small remote sample happens to be skewed toward healthcare postings rather than remote work in general asking for those skills. I'm reporting this as a limitation, not a finding about remote work.

## Data source

[Data Science Job Postings and Skills](https://www.kaggle.com/datasets/asaniczka/data-science-job-postings-and-skills) by asaniczka, on Kaggle. Scraped from LinkedIn, with job postings, their individually listed skills, and job summaries split across three files. I used `job_postings.csv` and `job_skills.csv`.

## Methodology

I filtered the roughly 1,300 real job titles down to postings for Data Analyst, Data Scientist, and Data Engineer specifically, using a substring match on job_title (more on why below), then joined that against the skills file to answer all four questions above.

The skills file stores every posting's skills as one comma-separated string per row, so before I could do anything with it in SQL, I reshaped it in Excel using Power Query's Split Column by Delimiter, with the "Split into Rows" option, turning one row of six skills into six rows of one skill each. I did the same cleaning and aggregation almost entirely in SQL (SQLite), rather than Python, as a deliberate choice to get more SQL practice: GROUP BY aggregation, a self-join for the skill co-occurrence question, CASE WHEN logic for cleaning up skill names, and RANK() as a window function to compare top skills across groups.

## Process and challenges

**The field I assumed would work for filtering, didn't.** I expected search_position, a column that looked like it held the search term used to find each posting, to let me filter cleanly. It didn't; a posting titled "Senior Machine Learning Engineer" had search_position listed as "Agricultural-Research Engineer," completely unrelated. That column turned out to be some kind of scraping artifact, not usable for anything. I switched to filtering on job_title instead, which is messier (free text written by whoever posted the job) but at least means what it says.

**A filter that missed a real pattern.** My first version of the job_title filter matched "data analyst," "data scientist," and "data engineer" as substrings. Checking the titles that got excluded, I noticed a batch of real Data Scientist roles weren't matching at all, titles like "Senior Manager, Data Science" and "AI Data Science Lead" use the noun form "Data Science" rather than "Data Scientist," so they slipped through untouched. I added "data science" as a fourth pattern once I caught this by actually reading the excluded list rather than trusting the filter on faith.

**A header row that refused to behave.** After reshaping the skills file in Power Query and exporting it, importing it into SQLite gave me two columns literally named Column1 and Column2, with the real header text sitting in the table as a data row instead of being recognized as a header. Re-importing with the "column names in first line" box checked didn't fix it. The actual fix was to stop fighting the import and handle it in SQL directly: rename the columns with ALTER TABLE, then delete the one row where the column still held the literal word "job_link," which was the stray header masquerading as data.

**Leftover whitespace from the split.** The comma-separated skills in the original data had a space after each comma, so after splitting into rows, every skill except the first one in each posting came out with a leading space, "Python" and " Python" would otherwise have been counted as two different skills. A Trim step in Power Query fixed it before I ever brought the data into SQL.

**The same skill, counted twice.** Early results showed "communication" and "communication skills" as two separate rows, clearly the same thing written two different ways in the source data. Rather than patch this in three different queries, I built one small SQL view that normalizes skill names in a single place, the same idea as the typo-fixing lookup table from my first project, just applied to wording instead of spelling.

**A view that broke on the second run.** Early on, rerunning my script failed with "view target_postings already exists," since SQLite doesn't let you recreate a view that's already there. I added DROP VIEW IF EXISTS before each CREATE VIEW so the whole script could be rerun safely from the top, which turned out to matter a lot once I was iterating on the filter and the skill-cleaning logic.

**Learning the hard way that DB Browser stops at the first error.** I'd assumed a one-time fix (renaming those Column1/Column2 columns) could just stay at the top of the script, reasoning that it would fail harmlessly once already applied and the rest of the script would keep running. That's wrong: DB Browser halts the whole script at the first error instead of skipping past it, so that "harmless" failure was actually blocking every query below it on every rerun. Once I noticed nothing after that point was producing results, I removed the one-time fix from the script entirely.

**The remote/on-site field turned out to be broken, not just imbalanced.** I expected job_type to have a mix of Onsite, Remote, and Hybrid values I could group by. Instead it was Onsite for all but two postings out of 4,660. Rather than report "no data," I checked whether remote status was captured anywhere else, and found 44 postings that mentioned "remote" directly in the job title or location. That's a workable but small sample, and I made sure to flag in the findings that the skills showing up in it may reflect which industries happened to post remote jobs in this scrape, not some general truth about remote work.

**Fitting the dashboard together took longer than the charts.** The charts themselves were quick, but getting them to sit properly on one dashboard was fiddly. My first headline text filled the entire canvas, the three headline tiles kept landing in the wrong row, and the default font made them look like typewriter text. Setting a fixed dashboard size, dropping each piece into the right half of its neighbour, and fixing the fonts one tile at a time sorted it out. The Remote versus On-site chart also got squashed when I set it to fit the whole view, so I switched it to fit the width instead and kept every skill readable.

**Catching a typo in a headline.** When I reviewed the finished dashboard I noticed the remote chart's title said "Online" instead of "On-site." It was a small slip, but it would have sat at the bottom of a public portfolio piece, so I now read every title out loud before publishing.

## Tools used

SQL (SQLite), for all filtering, aggregation, self-joins, and window functions. Excel (Power Query), for reshaping the comma-separated skills column into one row per skill. Tableau Public, for the dashboard. No Python was involved in this project, by choice.

## Files

| File | Description |
|---|---|
| `job_market_queries.sql` | All SQL: role filtering, skill normalization, and the four analysis questions |
| `job_skills_long.csv` | Skills data after the Power Query split, one skill per row |
| `tableau_data/` | The four small CSV files I exported from the SQL results to feed the Tableau dashboard |

Not included in this repo: the raw `job_postings.csv` and `job_skills.csv` (download from Kaggle to reproduce this) and `job_market.db` (regenerated locally by importing the two CSVs into SQLite).

## Reproducing this analysis

1. Download `job_postings.csv` and `job_skills.csv` from the [Kaggle dataset](https://www.kaggle.com/datasets/asaniczka/data-science-job-postings-and-skills).
2. In Excel, load `job_skills.csv` into Power Query, split the skills column by comma with "Split into Rows," trim the result, and export it as `job_skills_long.csv`.
3. In DB Browser for SQLite, create a new database and import both `job_postings.csv` and `job_skills_long.csv` as tables named `job_postings` and `job_skills_long`.
4. Run `job_market_queries.sql` from the top.

## Caveats

The role filter matches on substrings of job_title, which means a handful of real data roles with unusual titles, like "Data/Process Analyst" or "ETL Data Warehouse Specialist," aren't included. This was a deliberate tradeoff toward a cleaner, more precise match rather than catching every possible variant. The remote-versus-on-site comparison is based on just 44 postings identified by a text search, not a reliable field in the data, and should be read as a limited, directional look rather than a confident finding. Skill name cleanup only covers the one duplicate (communication / communication skills) I happened to spot; other wording variants may still exist uncaught in the raw data.
