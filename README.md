# CITS4407 Assignment 2

Name: Aakarsh Sagar Mahajan  
Student Number: 25152118  
Date: 22 May 2026

## What this is about

This assignment has two parts. First i had to clean up some messy YouTube
trending video data, and then analyse the cleaned version to pull out some
useful statistics. Both parts are written as Bash scripts using Unix tools
like awk and sed.

## Files

- `clean` — reads the raw unclean CSV and outputs a cleaned version
- `analyse` — reads the cleaned CSV and prints out 5 statistics

## The Data

The raw file `trending_videos_unclean.csv` has 7 columns:
`video_id`, `publish_date`, `views`, `likes`, `dislikes`, `comments_disabled`, `ratings_disabled`

After running clean, you get a 6 column version where the `ratings_disabled`
column is removed, the timestamp is stripped from `publish_date`, and all
the bad/duplicate/empty rows are gone.

## Running clean

```bash
./clean trending_videos_unclean.csv
```

This prints the cleaned data to standard output. The script checks for these
errors first:
- no file given
- file not found
- not a CSV file
- empty file
- wrong number of columns in the header (expects 7)

Then it cleans the data by:
- removing the `ratings_disabled` column
- removing rows with any empty fields
- removing rows where likes or dislikes are zero
- stripping the time from `publish_date` so it becomes just `YYYY-MM-DD`
- removing duplicate rows

## Running analyse

```bash
./analyse trending_videos_clean.csv
```

This prints 5 things about the data:
- which `video_id` appears the most
- the mean number of views (2 decimal places)
- which `video_id` has the most dislikes
- which video has the highest engagement rate — `(likes + dislikes) / views`
- which video has the least sentiment rate — `(likes - dislikes) / views`

Expected output:
```
Most frequent video, ID: id4667
Mean number of views: 2355595.97
Max dislikes video, ID: id2798
Highest engagement rate video, ID: id2282, dated: 2018-01-04
Least sentiment rate video, ID: id2219 , dated: 2017-12-13
```

If two or more videos tie on any metric, all of them are printed.
