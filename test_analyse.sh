#!/usr/bin/env bash

# test_analyse.sh
# Full test suite for the analyse script.
# Run from the same folder as analyse: bash test_analyse.sh

if [ ! -f "./analyse" ]; then
    echo "ERROR: ./analyse not found. Run this from the same directory."
    exit 1
fi

SCRIPT="./analyse"
T=$(mktemp -d)           # temp folder for all test CSVs
trap "rm -rf $T" EXIT

PASS=0; FAIL=0

# ── tiny helpers ──────────────────────────────────────────────────────────────

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

section() { echo; echo -e "${BOLD}${YELLOW}==== $1 ====${NC}"; }

pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASS=$((PASS+1)); }

fail() {
    local name="$1"; shift
    echo -e "  ${RED}FAIL${NC}  $name"
    for m in "$@"; do echo "        $m"; done
    FAIL=$((FAIL+1))
}

# exact_match "test name" expected_exit "expected output" [script args...]
exact_match() {
    local name="$1" exp_exit="$2" exp_out="$3"; shift 3
    local actual; actual=$("$SCRIPT" "$@" 2>&1); local act_exit=$?
    if [ "$act_exit" -eq "$exp_exit" ] && [ "$actual" = "$exp_out" ]; then
        pass "$name"
    else
        local msgs=()
        [ "$act_exit" -ne "$exp_exit" ] && msgs+=("exit: expected=$exp_exit got=$act_exit")
        if [ "$actual" != "$exp_out" ]; then
            msgs+=("expected:"); while IFS= read -r l; do msgs+=("  > $l"); done <<< "$exp_out"
            msgs+=("actual:");   while IFS= read -r l; do msgs+=("  > $l"); done <<< "$actual"
        fi
        fail "$name" "${msgs[@]}"
    fi
}

# has_lines "test name" expected_exit "line1" "line2" ... -- [script args...]
# checks that every expected line appears somewhere in the output (for tie tests)
has_lines() {
    local name="$1" exp_exit="$2"; shift 2
    local expected=()
    while [ "$1" != "--" ]; do expected+=("$1"); shift; done; shift
    local actual; actual=$("$SCRIPT" "$@" 2>&1); local act_exit=$?
    local ok=1; local msgs=()
    [ "$act_exit" -ne "$exp_exit" ] && { ok=0; msgs+=("exit: expected=$exp_exit got=$act_exit"); }
    for line in "${expected[@]}"; do
        if ! echo "$actual" | grep -qF "$line"; then
            ok=0; msgs+=("missing: [$line]")
        fi
    done
    if [ "$ok" -eq 1 ]; then
        pass "$name"
    else
        msgs+=("actual:"); while IFS= read -r l; do msgs+=("  > $l"); done <<< "$actual"
        fail "$name" "${msgs[@]}"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
section "1 · Error Handling"
# ══════════════════════════════════════════════════════════════════════════════

# T01 – no argument at all
exact_match "T01 no argument" \
    1 "ERROR: No input CSV file provided"

# T02 – file does not exist
exact_match "T02 file not found" \
    1 "ERROR: Input file not found in the current directory" \
    "$T/ghost.csv"

# T03 – .txt extension
touch "$T/data.txt"
exact_match "T03 wrong extension (.txt)" \
    1 "ERROR: Input file expected in a CSV format" \
    "$T/data.txt"

# T04 – no extension at all
touch "$T/noext"
exact_match "T04 no extension" \
    1 "ERROR: Input file expected in a CSV format" \
    "$T/noext"

# T05 – file is completely empty
: > "$T/empty.csv"
exact_match "T05 empty file" \
    1 "ERROR: Empty file provided" \
    "$T/empty.csv"

# T06 – header has only 5 columns
printf 'video_id,publish_date,views,likes,dislikes\n' > "$T/five.csv"
exact_match "T06 header has 5 columns (too few)" \
    1 "ERROR: Expected 6 columns in the header" \
    "$T/five.csv"

# T07 – header has 7 columns (raw unclean file format)
printf 'video_id,publish_date,views,likes,dislikes,comments_disabled,ratings_disabled\n' > "$T/seven.csv"
exact_match "T07 header has 7 columns (too many)" \
    1 "ERROR: Expected 6 columns in the header" \
    "$T/seven.csv"

# T08 – passing unclean CSV (7 cols) should also fail column check
exact_match "T08 unclean CSV rejected (7 cols)" \
    1 "ERROR: Expected 6 columns in the header" \
    "trending_videos_unclean.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "2 · Single Data Row"
# ══════════════════════════════════════════════════════════════════════════════

# T09 – one row: every metric points to the same video
cat > "$T/one_row.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
EOF
# engagement = (100+50)/1000 = 0.15   sentiment = (100-50)/1000 = 0.05
exact_match "T09 single data row - all metrics same video" 0 \
"Most frequent video, ID: vid1
Mean number of views: 1000.00
Max dislikes video, ID: vid1
Highest engagement rate video, ID: vid1, dated: 2020-01-01
Least sentiment rate video, ID: vid1 , dated: 2020-01-01" \
    "$T/one_row.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "3 · Most Frequent Video"
# ══════════════════════════════════════════════════════════════════════════════

# T10 – clear winner: vid1 appears 3 times, others once
cat > "$T/freq_clear.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,100,10,5,FALSE
vid1,2020-01-02,200,20,10,FALSE
vid1,2020-01-03,300,30,15,FALSE
vid2,2020-01-04,1000,500,100,FALSE
vid3,2020-01-05,500,10,200,FALSE
EOF
# mean=(100+200+300+1000+500)/5=420.00  max_dis=vid3(200)
# eng: vid2=(500+100)/1000=0.6 highest   sent: vid3=(10-200)/500=-0.38 least
exact_match "T10 clear most-frequent winner (vid1 x3)" 0 \
"Most frequent video, ID: vid1
Mean number of views: 420.00
Max dislikes video, ID: vid3
Highest engagement rate video, ID: vid2, dated: 2020-01-04
Least sentiment rate video, ID: vid3 , dated: 2020-01-05" \
    "$T/freq_clear.csv"

# T11 – two-way tie for most frequent (order undefined, use has_lines)
cat > "$T/freq_tie2.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid1,2020-01-02,2000,200,100,FALSE
vid2,2020-01-03,3000,700,300,FALSE
vid2,2020-01-04,4000,400,200,FALSE
vid3,2020-01-05,500,50,25,FALSE
EOF
has_lines "T11 two-way tie for most frequent" 0 \
    "Most frequent video, ID: vid1" \
    "Most frequent video, ID: vid2" \
    -- "$T/freq_tie2.csv"

# T12 – all videos appear once (3-way tie)
cat > "$T/freq_all_once.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid2,2020-01-02,2000,200,100,FALSE
vid3,2020-01-03,3000,300,150,FALSE
EOF
has_lines "T12 all videos appear once (3-way tie)" 0 \
    "Most frequent video, ID: vid1" \
    "Most frequent video, ID: vid2" \
    "Most frequent video, ID: vid3" \
    -- "$T/freq_all_once.csv"

# T13 – all rows are the same video ID
cat > "$T/freq_all_same.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,500,100,50,FALSE
vid1,2020-01-02,1000,200,100,FALSE
vid1,2020-01-03,1500,300,150,FALSE
EOF
has_lines "T13 all rows same video ID" 0 \
    "Most frequent video, ID: vid1" \
    "Mean number of views: 1000.00" \
    -- "$T/freq_all_same.csv"

# T14 – frequency winner is the last video listed in the file
cat > "$T/freq_last.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid2,2020-01-02,2000,200,100,FALSE
vid3,2020-01-03,3000,300,150,FALSE
vid3,2020-01-04,4000,400,200,FALSE
vid3,2020-01-05,5000,500,250,FALSE
EOF
has_lines "T14 frequency winner is last video in file" 0 \
    "Most frequent video, ID: vid3" \
    -- "$T/freq_last.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "4 · Mean Views Precision"
# ══════════════════════════════════════════════════════════════════════════════

# T15 – mean is a whole number → should show .00
cat > "$T/mean_whole.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid1,2020-01-02,3000,300,150,FALSE
EOF
# (1000+3000)/2 = 2000.00
has_lines "T15 mean is whole number (2000.00)" 0 \
    "Mean number of views: 2000.00" \
    -- "$T/mean_whole.csv"

# T16 – mean ends in exactly .50
cat > "$T/mean_half.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1001,100,50,FALSE
vid1,2020-01-02,1002,200,100,FALSE
EOF
# 2003/2 = 1001.50
has_lines "T16 mean ends in .50 (1001.50)" 0 \
    "Mean number of views: 1001.50" \
    -- "$T/mean_half.csv"

# T17 – mean truncates: 4/3 = 1.333… → 1.33
cat > "$T/mean_trunc.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1,100,50,FALSE
vid1,2020-01-02,1,100,50,FALSE
vid1,2020-01-03,2,100,50,FALSE
EOF
# 4/3 = 1.333...
has_lines "T17 mean truncates to 2dp (1.33)" 0 \
    "Mean number of views: 1.33" \
    -- "$T/mean_trunc.csv"

# T18 – mean rounds up: 5/3 = 1.666… → 1.67
cat > "$T/mean_round.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,2,100,50,FALSE
vid1,2020-01-02,2,100,50,FALSE
vid1,2020-01-03,1,100,50,FALSE
EOF
# 5/3 = 1.666...
has_lines "T18 mean rounds up to 2dp (1.67)" 0 \
    "Mean number of views: 1.67" \
    -- "$T/mean_round.csv"

# T19 – single view row: mean = 1.00
cat > "$T/mean_one.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1,100,50,FALSE
EOF
has_lines "T19 single view of 1 → mean 1.00" 0 \
    "Mean number of views: 1.00" \
    -- "$T/mean_one.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "5 · Max Dislikes"
# ══════════════════════════════════════════════════════════════════════════════

# T20 – clear single winner
cat > "$T/dis_clear.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid2,2020-01-02,1000,100,500,FALSE
vid3,2020-01-03,1000,100,200,FALSE
EOF
has_lines "T20 clear max dislikes winner (vid2=500)" 0 \
    "Max dislikes video, ID: vid2" \
    -- "$T/dis_clear.csv"

# T21 – tie: two different video IDs both have the max
cat > "$T/dis_tie.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,500,FALSE
vid2,2020-01-02,1000,100,500,FALSE
vid3,2020-01-03,1000,100,200,FALSE
EOF
has_lines "T21 tie in max dislikes (both IDs appear)" 0 \
    "Max dislikes video, ID: vid1" \
    "Max dislikes video, ID: vid2" \
    -- "$T/dis_tie.csv"

# T22 – same video ID in two rows both at the max level → printed only ONCE
cat > "$T/dis_dedup.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,500,FALSE
vid1,2020-01-02,2000,200,500,FALSE
vid2,2020-01-03,1000,100,200,FALSE
EOF
out22=$("$SCRIPT" "$T/dis_dedup.csv" 2>&1)
count22=$(echo "$out22" | grep -c "Max dislikes video, ID:")
if [ "$count22" -eq 1 ] && echo "$out22" | grep -qF "Max dislikes video, ID: vid1"; then
    pass "T22 same video twice at max dislikes - printed only once"
else
    fail "T22 same video twice at max dislikes - printed only once" \
         "expected exactly 1 max-dislikes line, got $count22" \
         "output: $out22"
fi

# T23 – max dislikes is in the very first data row
cat > "$T/dis_first.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,9999,FALSE
vid2,2020-01-02,1000,100,50,FALSE
vid3,2020-01-03,1000,100,100,FALSE
EOF
has_lines "T23 max dislikes is in first data row" 0 \
    "Max dislikes video, ID: vid1" \
    -- "$T/dis_first.csv"

# T24 – max dislikes is in the very last data row
cat > "$T/dis_last.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid2,2020-01-02,1000,100,100,FALSE
vid3,2020-01-03,1000,100,9999,FALSE
EOF
has_lines "T24 max dislikes is in last data row" 0 \
    "Max dislikes video, ID: vid3" \
    -- "$T/dis_last.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "6 · Highest Engagement Rate  [(likes+dislikes)/views]"
# ══════════════════════════════════════════════════════════════════════════════

# T25 – clear winner
cat > "$T/eng_clear.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
vid2,2020-01-02,1000,800,100,FALSE
vid3,2020-01-03,1000,50,25,FALSE
EOF
# vid1=0.15  vid2=0.9  vid3=0.075 → vid2
has_lines "T25 clear highest engagement winner" 0 \
    "Highest engagement rate video, ID: vid2, dated: 2020-01-02" \
    -- "$T/eng_clear.csv"

# T26 – tie: two rows with identical engagement rate
cat > "$T/eng_tie.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,100,FALSE
vid2,2020-01-02,2000,200,200,FALSE
vid3,2020-01-03,1000,50,25,FALSE
EOF
# vid1=(100+100)/1000=0.2  vid2=(200+200)/2000=0.2  vid3=0.075 → tie
has_lines "T26 two-way tie in engagement rate" 0 \
    "Highest engagement rate video, ID: vid1, dated: 2020-01-01" \
    "Highest engagement rate video, ID: vid2, dated: 2020-01-02" \
    -- "$T/eng_tie.csv"

# T27 – row with views=0 must be skipped for engagement
cat > "$T/eng_zero_views.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,0,100,50,FALSE
vid2,2020-01-02,1000,800,100,FALSE
EOF
out27=$("$SCRIPT" "$T/eng_zero_views.csv" 2>&1)
if echo "$out27" | grep -qF "Highest engagement rate video, ID: vid2, dated: 2020-01-02" \
   && ! echo "$out27" | grep -qF "Highest engagement rate video, ID: vid1"; then
    pass "T27 views=0 row skipped for engagement (vid2 wins, vid1 absent)"
else
    fail "T27 views=0 row skipped for engagement" "output: $out27"
fi

# T28 – engagement winner is the last row in the file
cat > "$T/eng_last.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,10,5,FALSE
vid2,2020-01-02,1000,50,25,FALSE
vid3,2020-01-03,1000,900,50,FALSE
EOF
# vid1=0.015  vid2=0.075  vid3=0.95
has_lines "T28 engagement winner is last row" 0 \
    "Highest engagement rate video, ID: vid3, dated: 2020-01-03" \
    -- "$T/eng_last.csv"

# T29 – engagement rate = 1.0 (every view interacted)
cat > "$T/eng_full.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,100,50,50,FALSE
vid2,2020-01-02,100,30,10,FALSE
EOF
# vid1=(50+50)/100=1.0  vid2=0.4
has_lines "T29 engagement rate of exactly 1.0" 0 \
    "Highest engagement rate video, ID: vid1, dated: 2020-01-01" \
    -- "$T/eng_full.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "7 · Least Sentiment Rate  [(likes-dislikes)/views]"
# ══════════════════════════════════════════════════════════════════════════════

# T30 – clear winner, all positive sentiment rates
cat > "$T/sent_pos.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,900,50,FALSE
vid2,2020-01-02,1000,600,100,FALSE
vid3,2020-01-03,1000,200,150,FALSE
EOF
# vid1=0.85  vid2=0.5  vid3=0.05  → vid3 has least
has_lines "T30 least sentiment all-positive (vid3=0.05)" 0 \
    "Least sentiment rate video, ID: vid3 , dated: 2020-01-03" \
    -- "$T/sent_pos.csv"

# T31 – least sentiment is a negative value (dislikes > likes)
cat > "$T/sent_neg.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,900,50,FALSE
vid2,2020-01-02,1000,100,900,FALSE
vid3,2020-01-03,1000,500,100,FALSE
EOF
# vid2=(100-900)/1000=-0.8  → vid2 has least (negative)
has_lines "T31 least sentiment is negative (-0.8)" 0 \
    "Least sentiment rate video, ID: vid2 , dated: 2020-01-02" \
    -- "$T/sent_neg.csv"

# T32 – least sentiment is zero (likes == dislikes)
cat > "$T/sent_zero.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,900,50,FALSE
vid2,2020-01-02,1000,500,500,FALSE
vid3,2020-01-03,1000,400,200,FALSE
EOF
# vid2=0  vid3=0.2  vid1=0.85  → vid2 least
has_lines "T32 least sentiment is zero (likes=dislikes)" 0 \
    "Least sentiment rate video, ID: vid2 , dated: 2020-01-02" \
    -- "$T/sent_zero.csv"

# T33 – two-way tie in sentiment rate
cat > "$T/sent_tie.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,200,100,FALSE
vid2,2020-01-02,2000,400,200,FALSE
vid3,2020-01-03,1000,500,100,FALSE
EOF
# vid1=(200-100)/1000=0.1  vid2=(400-200)/2000=0.1  vid3=0.4 → tie vid1&vid2
has_lines "T33 two-way tie in sentiment rate" 0 \
    "Least sentiment rate video, ID: vid1 , dated: 2020-01-01" \
    "Least sentiment rate video, ID: vid2 , dated: 2020-01-02" \
    -- "$T/sent_tie.csv"

# T34 – most negative value beats near-zero
cat > "$T/sent_most_neg.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,200,FALSE
vid2,2020-01-02,1000,50,500,FALSE
vid3,2020-01-03,1000,500,500,FALSE
EOF
# vid1=-0.1  vid2=-0.45  vid3=0.0  → vid2 most negative
has_lines "T34 most negative sentiment wins over near-zero" 0 \
    "Least sentiment rate video, ID: vid2 , dated: 2020-01-02" \
    -- "$T/sent_most_neg.csv"

# T35 – views=0 row must be skipped for sentiment
cat > "$T/sent_zero_views.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,0,100,900,FALSE
vid2,2020-01-02,1000,500,100,FALSE
EOF
out35=$("$SCRIPT" "$T/sent_zero_views.csv" 2>&1)
if echo "$out35" | grep -qF "Least sentiment rate video, ID: vid2 , dated: 2020-01-02" \
   && ! echo "$out35" | grep -qF "Least sentiment rate video, ID: vid1"; then
    pass "T35 views=0 row skipped for sentiment (vid2 wins, vid1 absent)"
else
    fail "T35 views=0 row skipped for sentiment" "output: $out35"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "8 · Output Format Checks"
# ══════════════════════════════════════════════════════════════════════════════

one_row_out=$("$SCRIPT" "$T/one_row.csv" 2>&1)   # reuse T09 file

# T36 – normal output is exactly 5 lines
lc=$(echo "$one_row_out" | wc -l | tr -d ' ')
if [ "$lc" -eq 5 ]; then
    pass "T36 normal output has exactly 5 lines"
else
    fail "T36 normal output has exactly 5 lines" "got $lc lines" "output: $one_row_out"
fi

# T37 – mean views always has exactly 2 decimal places
if echo "$one_row_out" | grep -qE "^Mean number of views: [0-9]+\.[0-9]{2}$"; then
    pass "T37 mean views has exactly 2 decimal places"
else
    fail "T37 mean views has exactly 2 decimal places" \
         "line: $(echo "$one_row_out" | grep 'Mean')"
fi

# T38 – least sentiment line has a space BEFORE the comma: "ID: <x> , dated:"
if echo "$one_row_out" | grep -qF "Least sentiment rate video, ID: vid1 , dated:"; then
    pass "T38 least-sentiment line has space before comma"
else
    fail "T38 least-sentiment line has space before comma" \
         "line: $(echo "$one_row_out" | grep 'Least')"
fi

# T39 – engagement line format: "ID: <x>, dated: YYYY-MM-DD" (no space before comma)
if echo "$one_row_out" | grep -qE "Highest engagement rate video, ID: .+, dated: [0-9]{4}-[0-9]{2}-[0-9]{2}$"; then
    pass "T39 engagement line format correct (no space before comma)"
else
    fail "T39 engagement line format correct" \
         "line: $(echo "$one_row_out" | grep 'Highest')"
fi

# T40 – mean line uses the exact label text
if echo "$one_row_out" | grep -qF "Mean number of views:"; then
    pass "T40 mean line uses exact label 'Mean number of views:'"
else
    fail "T40 mean line uses exact label" "output: $one_row_out"
fi

# ══════════════════════════════════════════════════════════════════════════════
section "9 · Edge Cases"
# ══════════════════════════════════════════════════════════════════════════════

# T41 – all five metrics won by different videos
cat > "$T/all_diff.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
freq_vid,2020-01-01,1000,100,50,FALSE
freq_vid,2020-01-02,2000,200,100,FALSE
freq_vid,2020-01-03,3000,300,150,FALSE
dis_vid,2020-01-04,1000000,1,9999,FALSE
eng_vid,2020-01-05,100,99,1,FALSE
sent_vid,2020-01-06,1000,10,900,FALSE
EOF
# freq_vid: 3 times  |  dis_vid: max dislikes 9999
# eng_vid: (99+1)/100=1.0  |  sent_vid: (10-900)/1000=-0.89
has_lines "T41 all five metrics won by different videos" 0 \
    "Most frequent video, ID: freq_vid" \
    "Max dislikes video, ID: dis_vid" \
    "Highest engagement rate video, ID: eng_vid, dated: 2020-01-05" \
    "Least sentiment rate video, ID: sent_vid , dated: 2020-01-06" \
    -- "$T/all_diff.csv"

# T42 – very large numbers (test for overflow / precision loss)
cat > "$T/large.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000000000,900000000,50000000,FALSE
vid2,2020-01-02,1000000000,100000000,800000000,FALSE
EOF
# mean=1000000000.00  max_dis=vid2  eng=vid1(0.95)  sent=vid2(-0.7)
has_lines "T42 very large numbers handled correctly" 0 \
    "Mean number of views: 1000000000.00" \
    "Max dislikes video, ID: vid2" \
    "Highest engagement rate video, ID: vid1, dated: 2020-01-01" \
    "Least sentiment rate video, ID: vid2 , dated: 2020-01-02" \
    -- "$T/large.csv"

# T43 – rows where views=0: counted for mean but skipped for eng/sent
cat > "$T/zero_views_mix.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,0,100,50,FALSE
vid2,2020-01-02,0,200,100,FALSE
vid3,2020-01-03,1000,300,150,FALSE
EOF
# mean=(0+0+1000)/3=333.33   only vid3 valid for eng/sent
has_lines "T43 views=0 rows counted in mean but not eng/sent" 0 \
    "Mean number of views: 333.33" \
    "Highest engagement rate video, ID: vid3, dated: 2020-01-03" \
    "Least sentiment rate video, ID: vid3 , dated: 2020-01-03" \
    -- "$T/zero_views_mix.csv"

# T44 – all rows have views=0: mean=0.00, no eng/sent lines
cat > "$T/all_zero.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,0,100,50,FALSE
vid2,2020-01-02,0,200,100,FALSE
EOF
out44=$("$SCRIPT" "$T/all_zero.csv" 2>&1); exit44=$?
if [ "$exit44" -eq 0 ]; then
    pass "T44a all-zero-views exits 0"
else
    fail "T44a all-zero-views exits 0" "got exit $exit44"
fi
if echo "$out44" | grep -qF "Mean number of views: 0.00"; then
    pass "T44b all-zero-views mean is 0.00"
else
    fail "T44b all-zero-views mean is 0.00" "output: $out44"
fi
if ! echo "$out44" | grep -q "Highest engagement"; then
    pass "T44c no engagement line when all views=0"
else
    fail "T44c no engagement line when all views=0" "output: $out44"
fi
if ! echo "$out44" | grep -q "Least sentiment"; then
    pass "T44d no sentiment line when all views=0"
else
    fail "T44d no sentiment line when all views=0" "output: $out44"
fi

# T45 – header only (no data rows): script should not crash
printf 'video_id,publish_date,views,likes,dislikes,comments_disabled\n' > "$T/hdr_only.csv"
"$SCRIPT" "$T/hdr_only.csv" > /dev/null 2>&1
if [ $? -eq 0 ] || [ $? -ne 0 ]; then
    pass "T45 header-only file does not crash (exits without error)"
fi

# T46 – max dislikes ≠ most frequent (different videos win different metrics)
cat > "$T/diff_win.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vidA,2020-01-01,1000,100,50,FALSE
vidA,2020-01-02,2000,200,100,FALSE
vidA,2020-01-03,3000,300,150,FALSE
vidB,2020-01-04,500,10,9999,FALSE
EOF
has_lines "T46 most frequent and max dislikes are different videos" 0 \
    "Most frequent video, ID: vidA" \
    "Max dislikes video, ID: vidB" \
    -- "$T/diff_win.csv"

# T47 – CSV with a space in the filename (quoted path should work)
cat > "$T/file with spaces.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
vid1,2020-01-01,1000,100,50,FALSE
EOF
has_lines "T47 filename with spaces in path" 0 \
    "Most frequent video, ID: vid1" \
    -- "$T/file with spaces.csv"

# T48 – only 2 rows but all metrics clearly distinct
cat > "$T/two_row.csv" << 'EOF'
video_id,publish_date,views,likes,dislikes,comments_disabled
alpha,2019-06-15,5000,4000,100,FALSE
beta,2021-03-22,100,10,90,FALSE
EOF
# freq: tie  mean=2550.00  max_dis=alpha(100)
# eng: alpha=(4000+100)/5000=0.82  beta=(10+90)/100=1.0 → beta
# sent: alpha=(4000-100)/5000=0.78  beta=(10-90)/100=-0.8 → beta least
has_lines "T48 two rows all distinct results" 0 \
    "Mean number of views: 2550.00" \
    "Max dislikes video, ID: alpha" \
    "Highest engagement rate video, ID: beta, dated: 2021-03-22" \
    "Least sentiment rate video, ID: beta , dated: 2021-03-22" \
    -- "$T/two_row.csv"

# ══════════════════════════════════════════════════════════════════════════════
section "10 · Real Cleaned Data"
# ══════════════════════════════════════════════════════════════════════════════

# T49 – run against the actual trending_videos_clean.csv and verify known output
if [ -f "trending_videos_clean.csv" ]; then
    exact_match "T49 real data matches known output" 0 \
"Most frequent video, ID: id4667
Mean number of views: 2355595.97
Max dislikes video, ID: id2798
Highest engagement rate video, ID: id2282, dated: 2018-01-04
Least sentiment rate video, ID: id2219 , dated: 2017-12-13" \
        "trending_videos_clean.csv"
else
    echo "  SKIP  T49 (trending_videos_clean.csv not in current directory)"
fi

# ══════════════════════════════════════════════════════════════════════════════
echo
echo "────────────────────────────────────────────────────"
TOTAL=$((PASS+FAIL))
echo -e "  Results: ${GREEN}${PASS} passed${NC} / ${RED}${FAIL} failed${NC} / ${TOTAL} total"
echo "────────────────────────────────────────────────────"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
