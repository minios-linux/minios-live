#!/bin/bash
for file in $1/[01-09]*
do
   rm $file
   ln -s ../../scripts/$(basename $file) $file
done