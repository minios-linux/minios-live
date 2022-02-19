#!/bin/bash
for file in $1/*
do
    rm $file
    ln -s ../../scripts/$(basename $file) $file
done