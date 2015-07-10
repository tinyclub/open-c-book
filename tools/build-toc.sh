#!/bin/bash
#
# Build toc for markdown automatically
#

for i in *.markdown
do
    # Generate a random toc id to avoid conflict
    toc="toc_${RANDOM}_${RANDOM}_"

    # Generate table of content
    sed -i -e '2i\\' $i

    grep "^###* " -ur $i | grep -n "^#" | \
        sed -e "s/:/a/g;" |\
	sed -e "s/\([0-9]*\)a\(#[^ ]*\) \(.*\)/\1a\2 [\3](#$toc\1)/g" |\
	sed -e "s/#####/+            -   /g;s/####/+        -   /g" |\
	sed -e "s/###/+    -   /g;s/##/-   /g" |\
	xargs -i sed -i -e "{}" $i;

    sed -i -e '2i\\' $i
    sed -i -e "s/^+   /   /g;" $i

    # Replace the #* with h* + id info
    t=0
    for line in `grep -n "^##" $i | cut -d':' -f1`
    do
	((line+=t))
	((t++))
        sed -i -e "${line}i<span id=\"$toc$t\"></span>" $i
    done
done
