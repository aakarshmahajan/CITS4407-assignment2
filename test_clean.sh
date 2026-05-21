#!/usr/bin/env bash

# Name: Aakarsh Sagar Mahajan
# Date: 21 May 2026
#
# test_clean.sh - runs all possible test cases for the clean script
# covers all 5 error checks and every data-cleaning rule from the spec
#
# Usage: bash test_clean.sh

PASS=0
FAIL=0

# helper function - runs a test and checks expected output
check() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    if [ "$actual" = "$expected" ]; then
        echo "PASS: $test_name"
        PASS=$((PASS + 1))
    else
        echo "FAIL: $test_name"
        echo "  expected : $expected"
        echo "  actual   : $actual"
        FAIL=$((FAIL + 1))
    fi
}

# -----------------------------------------------------------------------
# ERROR CHECK TESTS
# -----------------------------------------------------------------------

echo ""
echo "=== ERROR CHECKS ==="
echo ""

# 1. no argument given
actual=$(./clean 2>/dev/null)
check "no argument given" \
    "ERROR: No input CSV file provided" \
    "$actual"

# 2. file does not exist
actual=$(./clean doesnotexist.csv 2>/dev/null)
check "file not found" \
    "ERROR: Input file not found in the current directory" \
    "$actual"

# 3. file is not a csv (wrong extension)
echo "some data" > /tmp/testfile.txt
actual=$(./clean /tmp/testfile.txt 2>/dev/null)
check "not a csv file (txt extension)" \
    "ERROR: Input file expected in a CSV format" \
    "$actual"
rm -f /tmp/testfile.txt

# also test with no extension at all
echo "some data" > /tmp/testfile
actual=$(./clean /tmp/testfile 2>/dev/null)
check "not a csv file (no extension)" \
    "ERROR: Input file expected in a CSV format" \
    "$actual"
rm -f /tmp/testfile

# 4. file exists but is empty
touch /tmp/empty.csv
actual=$(./clean /tmp/empty.csv 2>/dev/null)
check "empty file" \
    "ERROR: Empty file provided" \
    "$actual"
rm -f /tmp/empty.csv

# 5. header has wrong number of columns (too few)
printf "video_id,publish_date,views\n" > /tmp/toofew.csv
actual=$(./clean /tmp/toofew.csv 2>/dev/null)
check "header has too few columns (3)" \
    "ERROR: Expected 7 columns in the header" \
    "$actual"
rm -f /tmp/toofew.csv

# 5b. header has wrong number of columns (too many)
printf "video_id,publish_date,views,likes,dislikes,comments_disabled,ratings_disabled,extra\n" > /tmp/toomany.csv
actual=$(./clean /tmp/toomany.csv 2>/dev/null)
check "header has too many columns (8)" \
    "ERROR: Expected 7 columns in the header" \
    "$actual"
rm -f /tmp/toomany.csv

# -----------------------------------------------------------------------
# DATA CLEANING TESTS
# -----------------------------------------------------------------------

echo ""
echo "=== DATA CLEANING ==="
echo ""

HEADER="video_id,publish_date,views,likes,dislikes,comments_disabled,ratings_disabled"

# 6. valid row passes through (basic sanity check)
printf "%s\nid001,2017-11-09T18:01:04.000Z,5000,10,3,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv)
check "valid row is kept" \
    "video_id,publish_date,views,likes,dislikes,comments_disabled
id001,2017-11-09,5000,10,3,FALSE" \
    "$actual"

# 7. ratings_disabled column is dropped
printf "%s\nid002,2017-01-01T10:00:00.000Z,1000,5,2,TRUE,FALSE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | head -1)
check "ratings_disabled dropped from header" \
    "video_id,publish_date,views,likes,dislikes,comments_disabled" \
    "$actual"

# 8. timestamp stripped from publish_date
printf "%s\nid003,2009-09-18T15:36:33.000Z,2000,4,1,FALSE,FALSE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -1)
check "timestamp stripped from publish_date" \
    "id003,2009-09-18,2000,4,1,FALSE" \
    "$actual"

# 9. row with empty video_id is deleted
printf "%s\n,2017-11-09T18:01:04.000Z,5000,10,3,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with empty video_id deleted" \
    "" \
    "$actual"

# 10. row with empty publish_date is deleted
printf "%s\nid004,,5000,10,3,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with empty publish_date deleted" \
    "" \
    "$actual"

# 11. row with empty views is deleted
printf "%s\nid005,2017-11-09T18:01:04.000Z,,10,3,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with empty views deleted" \
    "" \
    "$actual"

# 12. row with empty likes is deleted
printf "%s\nid006,2017-11-09T18:01:04.000Z,5000,,3,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with empty likes deleted" \
    "" \
    "$actual"

# 13. row with empty dislikes is deleted
printf "%s\nid007,2017-11-09T18:01:04.000Z,5000,10,,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with empty dislikes deleted" \
    "" \
    "$actual"

# 14. row with empty comments_disabled is deleted
printf "%s\nid008,2017-11-09T18:01:04.000Z,5000,10,3,,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with empty comments_disabled deleted" \
    "" \
    "$actual"

# 15. row with zero likes is deleted
printf "%s\nid009,2017-11-09T18:01:04.000Z,5000,0,3,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with zero likes deleted" \
    "" \
    "$actual"

# 16. row with zero dislikes is deleted
printf "%s\nid010,2017-11-09T18:01:04.000Z,5000,10,0,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with zero dislikes deleted" \
    "" \
    "$actual"

# 17. row with zero likes AND zero dislikes is deleted
printf "%s\nid011,2017-11-09T18:01:04.000Z,5000,0,0,FALSE,TRUE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with zero likes and zero dislikes deleted" \
    "" \
    "$actual"

# 18. exact duplicate rows - only one copy kept
printf "%s\nid012,2017-01-01T10:00:00.000Z,1000,5,2,TRUE,FALSE\nid012,2017-01-01T10:00:00.000Z,1000,5,2,TRUE,FALSE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | grep "id012" | wc -l | tr -d ' ')
check "duplicate row appears only once" \
    "1" \
    "$actual"

# 19. two rows same id but different data - both kept (not duplicates)
printf "%s\nid013,2017-01-01T10:00:00.000Z,1000,5,2,TRUE,FALSE\nid013,2017-01-01T10:00:00.000Z,2000,8,3,TRUE,FALSE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | grep "id013" | wc -l | tr -d ' ')
check "same id different data - both rows kept" \
    "2" \
    "$actual"

# 20. row with too few fields is deleted
printf "%s\nid014,2017-11-09T18:01:04.000Z,5000,10\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with too few fields deleted" \
    "" \
    "$actual"

# 21. row with too many fields is deleted
printf "%s\nid015,2017-11-09T18:01:04.000Z,5000,10,3,FALSE,TRUE,EXTRA\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2)
check "row with too many fields deleted" \
    "" \
    "$actual"

# 22. mix of good and bad rows - only good ones pass
printf "%s\nid016,2017-01-01T10:00:00.000Z,3000,6,2,FALSE,FALSE\n,2017-01-01T10:00:00.000Z,3000,6,2,FALSE,FALSE\nid017,2018-05-10T08:00:00.000Z,8000,20,5,TRUE,FALSE\nid018,2018-05-10T08:00:00.000Z,8000,0,5,TRUE,FALSE\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv | tail -n +2 | wc -l | tr -d ' ')
check "mix of rows - only 2 valid ones pass" \
    "2" \
    "$actual"

# 23. header-only file (no data rows) - outputs just the new header
printf "%s\n" "$HEADER" > /tmp/test.csv
actual=$(./clean /tmp/test.csv)
check "header-only file outputs just new header" \
    "video_id,publish_date,views,likes,dislikes,comments_disabled" \
    "$actual"

# cleanup temp files
rm -f /tmp/test.csv

# -----------------------------------------------------------------------
# SUMMARY
# -----------------------------------------------------------------------

echo ""
echo "==============================="
echo "  PASSED : $PASS"
echo "  FAILED : $FAIL"
echo "  TOTAL  : $((PASS + FAIL))"
echo "==============================="
echo ""
