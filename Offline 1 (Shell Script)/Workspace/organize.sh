#!/bin/bash

unzip_submissions() {
    # unzip all the folders in $1
    for i in "$1"/*
    do
        if [ -f "$i" ] && [[ "$i" = *.zip ]]
        then
            # echo "filename is $i"
            dirname=${i::-4}
            # echo "dirname is $dirname"
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

run_tests() {
    for i in "$2"/*
    do
        if [ -f "$i" ] && [[ "$i" = *.txt ]]
        then
            dir=$(dirname "$1")
            cmd="$1"
            cmd+=" < "
            cmd+="$i"
            cmd+=" > "
            cmd+="$dir"
            cmd+="/out"
            num=$(basename "$i")
            num=${num:4}
            cmd+="$num"
            # echo "$cmd"
            eval " $cmd"
        fi
    done
}

execute_C_file() {
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="$i"
            executable_name="$i"
            file_name+="/main.c"
            executable_name+="/main.out"
            
            # compile
            gcc "$file_name" -o "$executable_name"

            # run the executables
            run_tests "$executable_name" "$2"
        fi
    done
}

execute_Java_file() {
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="$i"
            file_name+="/Main.java"
            javac "$file_name"
        fi
    done
}

execute_files() {
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            
            dir=$(basename "$i")
            # echo "dir is ${dir}"
            case "$dir" in
                "C") 
                    execute_C_file "$i" "$2";;
                "Java") 
                    execute_Java_file "$i";;
                "Python") 
                    echo "Can't understand.";;
            esac
            
        fi
    done
}

unzip_submissions "$1"

organize_files "$1" "$2"

execute_files "$2" "$3"
