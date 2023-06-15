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
            unzip -oq "$i" -d "$dirname"
        fi
    done
}

relocate_code_file() {
    target_dir="${2}${4}${3}"
    # target_dir+="$4"
    # target_dir+="$3"
    # echo "$target_dir"
    mkdir -p "$target_dir"
    cp "$1" "$target_dir"

    if [ "$filename" != "$5" ] 
    then
        target_file="${target_dir}/"
        # target_file+="/"
        new_target_file="${target_file}${5}"
        target_file+="$filename"
        # new_target_file+="$5"
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
            num=$(basename "$i")
            num=${num:4}
            cmd="${3} < ${i} > ${1}/out${num}"
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
            file_name="${i}/main.c"
            executable_name="${i}/main.out"
            
            # compile
            gcc "$file_name" -o "$executable_name"

            # run the executables
            dir=$(dirname "$file_name")
            cmd="${executable_name}"
            run_tests "$dir" "$2" "$cmd"
        fi
    done
}

execute_Java_file() {
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="${i}/Main.java"
            
            # compile
            javac "$file_name"

            # run the executables
            dir=$(dirname "$file_name")
            cmd="java -cp ${dir} Main"
            run_tests "$dir" "$2" "$cmd"
        fi
    done
}

execute_Python_file() {
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="${i}/main.py"

            # run the executables
            dir=$(dirname "$file_name")
            cmd="python3 ${file_name}"
            run_tests "$dir" "$2" "$cmd"
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
                    execute_Java_file "$i" "$2";;
                "Python") 
                    execute_Python_file "$i" "$2";;
            esac
            
        fi
    done
}

match_files() {
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            language=$(basename "$i")
            for j in "$i"/*
            do
                if [ -d "$j" ] 
                then
                    sid=$(basename "$j")
                    for k in "$j"/*
                    do
                        if [ -f "$k" ] && [[ "$k" = *.txt ]]
                        then
                            num=$(basename "$k")
                            num=${num:3}
                            ans_file="${2}/ans${num}"
                            dif=$(diff "$k" "$ans_file")
                            if [ "$dif" != "" ]
                            then
                                echo "unmatched"
                            fi
                        fi
                    done
                fi
            done
            
        fi
    done
}

unzip_submissions "$1"

organize_files "$1" "$2"

execute_files "$2" "$3"

match_files "$2" "$4"
