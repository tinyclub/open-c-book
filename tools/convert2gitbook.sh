#!/bin/bash
#
# convert2gitbook.sh -- convert the old markdown book support to gitbook
#

LANG=zh

# Generate SUMMARY.md

find $LANG/ -name "*.markdown*" | xargs -i grep -Hr "^# " {} \
        | grep -v "define" | sort -t / -g -k 3 \
        | sed -e "s/\(.*\):# \(.*\)/* [\2](\1)/g" > SUMMARY.md

# Convert pic/cover.png to cover.jpg
# Note: config/basic.yml doesn't use pic/cover.png currently.

convert pic/cover.png cover.jpg

# copy images to zh/
cp -r pic/ zh/chapters/
cp -r pic/ zh/preface/
