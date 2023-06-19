#!/bin/bash

verbose_flag=false
noexec_flag=false

unzip_submissions() {
    # unzip all the folders in $1
    for i in "$1"/*
    do
        if [ -f "$i" ] && [[ "$i" = *.zip ]]
        then
            dirname=${i::-4} # create a folder and then unzip there to avoid messy extraction
            mkdir -p "$dirname"
            unzip -oq "$i" -d "$dirname" # unzip quietly
        fi
    done
}

relocate_code_file() {
    # $1 is code filepath
    # $2 is target directory
    # $3 is student_id
    # $4 is "C" or "Java" or "Python"
    # $5 is updated filename
    # $6 is curremt filename
    
    target_dir="${2}/${4}/${3}"
    mkdir -p "$target_dir"
    cp "$1" "$target_dir"

    filename="$6"

    if [ "$filename" != "$5" ] 
    then
        # rename file
        target_file="${target_dir}/"
        new_target_file="${target_file}${5}"
        target_file+="$filename"
        mv "$target_file" "$new_target_file"
    fi
}

visit()
{
	# $1 is current directory
    # $2 is target directory
    # $3 is student_id
    
    if [ -d "$1" ]
	then
	
		for i in "$1"/*
		do
			visit "$i" "$2" "$3" # recursively try to find the code file
		done
	
	elif [ -f "$1" ] && { [[ "$1" = *.c ]] || [[ "$1" = *.java ]] || [[ "$1" = *.py ]]; }
	then
        # filename="${i##*/}"
        filename=$(basename "$i")
        extension="${i##*.}"
        # dir=$(dirname "$i")
        
        if [ "$extension" = "c" ] 
        then
            relocate_code_file "$1" "$2" "$3" "C" "main.c" "$filename"
        elif [ "$extension" = "java" ] 
        then
            relocate_code_file "$1" "$2" "$3" "Java" "Main.java" "$filename"
        elif [ "$extension" = "py" ] 
        then
            relocate_code_file "$1" "$2" "$3" "Python" "main.py" "$filename"
        fi

	fi
}

organize_files() {
    # $1 is submissions folder
    # $2 is target folder
    
    mkdir -p "${2}/C"
    mkdir -p "${2}/Java"
    mkdir -p "${2}/Python"
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
           sid=${i: -7} # last 7 characters
           if [ $verbose_flag == "true" ]
           then
                echo "Organizing files of ${sid}"
           fi
           visit "$i" "$2" "$sid"
        fi
    done
}

run_tests() {
    # $1 is directory path of code file
    # $2 is tests directory
    # $3 is command to execute
    
    for i in "$2"/*
    do
        if [ -f "$i" ] && [[ "$i" = *.txt ]]
        then
            # $i is a input file
            num=$(basename "$i") 
            num=${num:4} # test number
            cmd="${3} < ${i} > ${1}/out${num}"
            eval " $cmd"
        fi
    done
}

execute_C_file() {
    # $1 is C directory
    # $2 is tests directory
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="${i}/main.c"
            executable_name="${i}/main.out"

            if [ $verbose_flag == "true" ]
            then
                echo "Executing files of ${sid}"
            fi
            
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
    # $1 is Java directory
    # $2 is tests directory
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="${i}/Main.java"

            if [ $verbose_flag == "true" ]
            then
                echo "Executing files of ${sid}"
            fi
            
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
    # $1 is Python directory
    # $2 is tests directory
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            sid=$(basename "$i")
            file_name="${i}/main.py"

            if [ $verbose_flag == "true" ]
            then
                echo "Executing files of ${sid}"
            fi

            # run the executables
            dir=$(dirname "$file_name")
            cmd="python3 ${file_name}"
            run_tests "$dir" "$2" "$cmd"
        fi
    done
}

execute_files() {
    # $1 is target directory
    # $2 is tests directory
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            
            dir=$(basename "$i")
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

# diff to find if output matches with answers
match_files() {
    # $1 is target directory where the output files are located
    # $2 is answers directory
    # $3 is csv filepath
    
    for i in "$1"/*
    do
        if [ -d "$i" ]
        then
            language=$(basename "$i") # C or Java or python
            for j in "$i"/*
            do
                if [ -d "$j" ] 
                then
                    sid=$(basename "$j")
                    matched=0
                    unmatched=0
                    for k in "$j"/*
                    do
                        if [ -f "$k" ] && [[ "$k" = *.txt ]]
                        then
                            num=$(basename "$k")
                            num=${num:3} # output number
                            ans_file="${2}/ans${num}"
                            dif=$(diff "$k" "$ans_file")
                            if [ "$dif" != "" ]
                            then
                                unmatched=$((unmatched+1))
                            else 
                                matched=$((matched+1))
                            fi
                        fi
                    done

                    # write in csv
                    echo "${sid},${language},${matched},${unmatched}" >> "$3"

                fi
            done
            
        fi
    done
}

count_test_files() {
    # $1 is tests directory
    
    cnt=0
    for i in "$1"/*
    do
        if [ -f "$i" ] && [[ "$i" = *.txt ]]
        then
            cnt=$((cnt+1))
        fi
    done
    echo "Found ${cnt} test files"
}

# Loop through the command-line arguments to check for switches
i=1
for arg in "$@"; do
    if [ "$i" -gt 4 ] 
    then
        if [ "$arg" = "-v" ] 
        then
            verbose_flag=true;
        elif [ "$arg" = "-noexecute" ] 
        then
            noexec_flag=true;
        fi
    fi
    i=$((i+1))
done

# check usage
if [ $# -lt 4 ]
then
    echo "Usage:"
    echo "${0} <submission folder> <target folder> <test folder> <answer folder> [-v] [-noexecute]"
    echo ""
    echo "-v: verbose"
    echo "-noexecute: do not execute code files"
    kill -INT $$
fi

if [ $verbose_flag == "true" ]
then
    count_test_files "$3"
fi

unzip_submissions "$1"

rm -r "$2" # delete target directory if already exists

organize_files "$1" "$2"

if [ "$noexec_flag" = "false" ]
then
    execute_files "$2" "$3"

    csv_path="${2}/results.csv"
    echo "student_id,type,matched,not_matched" > "$csv_path"

    match_files "$2" "$4" "$csv_path"
fi
