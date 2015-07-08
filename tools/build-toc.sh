#!/bin/bash
#
# Build toc automatically
#

for i in *.markdown
do

    sed -i -e "2i\n" $i

    grep "^##" -ur $i |\
        egrep -n -v "include|ifdef|endif|undef|define|ifndef|update|file|date|funct|author" |\
        sed -e "s/:/a/g;" |\
	sed -e "s/\(#[^ ]*\) \(.*\)/\1 [\2](#\2)/g" |\
	sed -e "s/#####/+            -   /g;s/####/+        -   /g" |\
	sed -e "s/###/+    -   /g;s/##/-   /g" |\
	xargs -i sed -i -e "{}" $i;

    sed -i -e "2i\n" $i
    sed -i -e "s/^+   /   /g" $i
    sed -i -e "s/^n//g" $i
done
