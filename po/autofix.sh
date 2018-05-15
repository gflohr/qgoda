#! /bin/sh

for file in *.po; do
        lingua=`echo $file | perl -p -e 's/\.po$//'`
        perl autofix.pl --input=$file --language=$lingua  --output=$file.new --verbose
        test -e $file.new && mv $file.new $file
done
