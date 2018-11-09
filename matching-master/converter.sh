#!/bin/bash

if [ -z "$1" ]
   then
       echo "No arguments supplied; please provide a directory to convert"
       exit 1
fi

for filename in ./$1/*; do
sed -i 's/^{/{\n\"applications\":\[{\n/g' "$filename"
sed -i 's/\"job_description\"/\"job_description\"/g' "$filename"
sed -i 's///g' "$filename"
sed -i 's/\([\[{]\)$/\n\1\n/g' "$filename"
sed -i 's/\[/\n\[\n/g' "$filename"
sed -i 's/{/\n{\n/g' "$filename"
sed -i 's/}\([^,]\)/\n}\n\1/g' "$filename"
sed -i 's/\]\([^,]\)/\n\]\n\1/g' "$filename"
sed -i "s/:\([^,]*,\)/:\1\n/g" "$filename"
sed -i 's/},/\n},\n/g' "$filename"
sed -i 's/\],/\n\],\n/g' "$filename"
sed -i 's/^\"}/}/g' "$filename"
sed -i 's/^\"\]/\]/g' "$filename"
sed -i "s/u'/'/g" "$filename"
sed -i "s/'/\"/g" "$filename"
sed -i '/^$/d' "$filename"
echo ] >> "$filename"
echo "\"end\":" >> "$filename"
echo } >> "$filename"
sed -i 's/ {$//g' "$filename"
sed -i ':a;N;$!ba;s/\n\[/ \[/g' "$filename"
sed -i 's/\(\"stages\":\"[^$]*$\)/\1 {/g' "$filename"
sed -i 's/^\([^j]*fileId*[^$]*$\)/\1\n}/g' "$filename"
sed -i 's/ \"en\": /\n\"en\":/g' "$filename"
sed -i 's/ \"fr\": /\n\"en\":/g' "$filename"
done
