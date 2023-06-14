#!/bin/bash

organize() {
    # unzip all the folders in $1
    for i in "$1"/*
    do
        if [ -f "$i" ] && [[ $i = *.zip ]]
        then
            echo "filename is $i"
            dirname=${i::-4}
            echo "dirname is $dirname"
            mkdir -p "$dirname"
            unzip "$i" -d "$dirname"
        fi
    done
}

organize "$1"
