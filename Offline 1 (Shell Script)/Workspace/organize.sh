#!/bin/bash

unzip_submissions() {
    # unzip all the folders in $1
    for i in "$1"/*
    do
        if [ -f "$i" ] && [[ "$i" = *.zip ]]
        then
            echo "filename is $i"
            dirname=${i::-4}
            echo "dirname is $dirname"
            mkdir -p "$dirname"
            unzip -o "$i" -d "$dirname"
        fi
    done
}

relocate_code_file() {
    target_dir="$2"
    target_dir+="$4"
    target_dir+="$3"
    # echo "$target_dir"
    mkdir -p "$target_dir"
    cp "$1" "$target_dir"

    if [ "$filename" != "$5" ] 
    then
        target_file="$target_dir"
        target_file+="/"
        new_target_file="$target_file"
        target_file+="$filename"
        new_target_file+="$5"
        mv "$target_file" "$new_target_file"
    fi
}

visit()
{
	if [ -d "$1" ]
	then
	
		for i in "$1"/*
		do
			visit "$i" "$2" "$3"
		done
	
	elif [ -f "$1" ] && { [[ "$1" = *.c ]] || [[ "$1" = *.java ]] || [[ "$1" = *.py ]]; }
	then
		# echo "$i"
        # filename="${i##*/}"
        # echo "$filename"
        filename=$(basename "$i")
        # echo "$filename"
        extension="${i##*.}"
        # echo "$extension"
        # dir=$(dirname "$i")
        # echo "$dir"
        
        if [ "$extension" = "c" ] 
        then
            relocate_code_file "$1" "$2" "$3" "/C/" "main.c"
        elif [ "$extension" = "java" ] 
        then
            relocate_code_file "$1" "$2" "$3" "/Java/" "Main.java"
        elif [ "$extension" = "py" ] 
        then
            relocate_code_file "$1" "$2" "$3" "/Python/" "main.py"
        fi

	fi
}

organize_files() {
    mkdir -p "${2}/C"
    mkdir -p "${2}/Java"
    mkdir -p "${2}/Python"
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
           sid=${i: -7} # last 7 characters 
           visit "$i" "$2" "$sid"
        fi
    done
}

unzip_submissions "$1"

organize_files "$1" "$2"
