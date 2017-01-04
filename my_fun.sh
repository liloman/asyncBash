# vim: set filetype=sh :
# asyncBash FUN
# Copyright © 2016 liloman

######################
#  MY asyncBASH FUN  #
######################

###############
#  Variables  #
###############

#For insert_relative_command_number functions
#set current cmdnumber for prompt 
declare -gi cmdnumber=0
#Current arrayhistory index position
declare -gi prev_historyid=0

#For search_substring_history functions
#Hold the result of the substring search
declare -ga arrayhistory
#Current position on arrayhistory
declare -gi currentSearchIdx=0
#Current substring searched for
declare -g  currentSearchArg=

###########
#  BINDS  #
###########

#Bind to insert relative command  number
#positive number for current session
# <=0 for older sessions ;)
bind -x '"\C-gr":insert_relative_command_number'

# Search for a substring *argument* into history 
# c-n dynamic-complete-history on steroids 
#Backward search
bind -x '"\C-gb1": search_substring_history backward'
#Forward search
bind -x '"\C-gb2": search_substring_history forward'

#Display a cheatsheet for the first command on the cli
bind -x '"\C-gb3": show_command_hints 0'
#Display a cheatsheet for the last command on the cli
bind -x '"\C-gb4": show_command_hints 1'
#Create/edit a cheatsheet for the first command
bind -x '"\C-gb5": edit_command_hint 0'
#Create/edit a cheatsheet for the last command
bind -x '"\C-gb6": edit_command_hint 1'

#Test for newlines on the bottom
bind -x '"\C-gb7": go_down'

########################
#  User defined hooks  #
########################

#Execute this when not an asyncBash call
asyncBash_after_out() {
    #reset substring history search if user forget enter Ctl-q to reset search
    currentSearchArg=
    currentSearchIdx=0
}

#Execute this when in an asyncBash call
asyncBash_before_in() { :; }

#Execute this after any command
asyncBash_on_hook()   { 
    #set cmdnumber 
    set_cmd_number
}


###############
#  Functions  #
###############

go_down(){
    #Clean possible previous asyncBash calls
    local -a cmda=($asyncBash_current_cmd_line "funciona")
    asyncBash_clean_screen_msgs
    asyncBash_add_msg_below_ps1 "go downs 0" 
    asyncBash_add_msg_below_ps1 "go downs 1" 
    asyncBash_add_msg_below_ps1 "go downs 2" 
    asyncBash_add_msg_below_ps1 "go downs 3" 
    asyncBash_add_msg_below_ps1 "go downs 4" 
    asyncBash_add_msg_below_ps1 "go downs 5" 
    #Substitute history line
    asyncBash_substitute_command_line "${cmda[@]:-1}"
}


#Display a cheatsheet for the current command
#from ~/.local/share/asyncBash/hints
edit_command_hint() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    #Clean possible previous asyncBash calls
    asyncBash_clean_screen_msgs
    local -a cmda=($asyncBash_current_cmd_line)
    local last=$1
    local cmd=
    (( $last )) && cmd=${cmda[-1]}  || cmd=${cmda[0]}
    local file="$HOME/.local/share/asyncBash/hints/$cmd.txt"

    if [[ $cmd == hints  ]]; then
        asyncBash_add_msg_below_ps1 "Can't edit $cmd command cause it's special" 
        #Substitute history line
        asyncBash_substitute_command_line "${cmda[@]:-1}"
        return
    fi

    if [[ -e $file  ]]; then
        #show a legend with the possible arguments
        asyncBash_add_msg_below_ps1 "editting the hint with $EDITOR" 
    else
        asyncBash_add_msg_below_ps1 "created a new file and editting it with $EDITOR" 
    fi
    $EDITOR $file
    #Substitute history line
    asyncBash_substitute_command_line "${cmda[@]:-1}"
}

#Display a cheatsheet for the current command
#from ~/.local/hints
show_command_hints() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    #Clean possible previous asyncBash calls
    asyncBash_clean_screen_msgs
    local -a cmda=($asyncBash_current_cmd_line)
    local last=$1
    local cmd=
    local keybin="Alt + e"
    if (( $last )); then
        cmd=${cmda[-1]} 
        keybin=$keybin" + l"
    else
        cmd=${cmda[0]}
        keybin=$keybin" + f"
    fi
    local path="$HOME/.local/share/asyncBash/hints"
    local file="$path/$cmd.txt"
    local i=0

    #create it if it doesn't exist
    [[ ! -e $path ]] && mkdir -p $path

    #special argument to list all the hints
    if [[ $cmd == hints  ]]; then
        for file in $(shopt -s dotglob;echo "$path/"*.txt); do
            file=${file##*/}; file=${file::-4}
            ((i)) || asyncBash_add_msg_below_ps1 "Listing all hints (use dhint/$EDITOR to remove one):"  
            ((i++))
            [[ $file == '*' ]] && break #no luck
            asyncBash_add_msg_below_ps1 "$i) $file"
        done
    elif [[ -e $file  ]]; then #exact match
        bind -x '"\C-q": asyncBash_clean_screen_msgs'
        asyncBash_add_msg_below_ps1 "Enter Control-q to clean screen messages" yes
        while IFS= read -r line; do 
            asyncBash_add_msg_below_ps1 "$line"
        done < $file
    else #don't found suggest similar hints
        bind -x '"\C-q": asyncBash_clean_screen_msgs'
        asyncBash_add_msg_below_ps1 "Enter Control-q to clean screen messages" yes
        asyncBash_add_msg_below_ps1 "You can created a new file or edit it with $EDITOR with $keybin" 

        for file in $(shopt -s dotglob;echo "$path/$cmd"*.txt); do
            file=${file##*/}; file=${file::-4}
            [[ $file == $cmd'*' ]] && break #no luck
            ((i)) || asyncBash_add_msg_below_ps1 "Exact match not found. Possible values are:"  
            ((i++))
            asyncBash_add_msg_below_ps1 "$i)${file}"
        done
    fi

    #Substitute history line
    asyncBash_substitute_command_line "${cmda[@]:-1}"
}

#1.Bash doesn't get into account of histcontrol and histignore with \#
#so you must roll on your on solution (cmdnumber).It's been reported to bash bug...
#2.HISTCMD(=asyncBash_historyid) doesn't work outside of readline because they are different processes
# in bash 4.4 you sould be able to use prompt expansion echo ${PS1@P}
set_cmd_number() {
    if ((prev_historyid!=asyncBash_historyid));then
        if ((!asyncBash_flag_on)); then
            ((cmdnumber++)) 
            prev_historyid=asyncBash_historyid
        fi
    fi
}


#Insert the relative command number from the actual
insert_relative_command_number() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    #Show a legend below prompt with the arguments of a relative command number
    show_relative_command_number_args() {
        #get history id
        local -i id=$((asyncBash_historyid-$1))
        local hist=$(fc -nlr $id $id)
        local -a hista=($hist)
        local idx=
        local msg=
        local args="*)"
        for idx in "${!hista[@]}";do
            msg+="$idx) ${hista[$idx]}    "
            ((idx>0)) && args+=" ${hista[$idx]} "
        done

        asyncBash_add_msg_below_ps1 "$msg  $args"
    }
    #Clean possible previous asyncBash calls
    asyncBash_clean_screen_msgs
    local -a cmda=($asyncBash_current_cmd_line)
    #get last argument index
    local idx=$((${#cmda[@]}-1))
    #get last argument
    local arg=${cmda[$idx]}
    local dest=

    if [[ ! $arg =~ ^-?[0-9]+([0-9]+)?$ ]]; then
        asyncBash_add_msg_below_ps1 "error:$arg is not a number"
        return
    fi
    #substract the current command number with the destiny (last argument)
    #works with 0...-N to go before current session... :)
    if (( cmdnumber > arg )); then
        dest=!-$((cmdnumber - arg)): 
        #do not tamper with shopt -s histverify
        asyncBash_add_msg_below_ps1 "empty" 
        #hook Ctrl-q to clean the messages without a msg
        bind -x '"\C-q": asyncBash_clean_screen_msgs'
        #show a legend with the possible arguments
        asyncBash_add_msg_below_ps1 "Enter Control-q to clean screen messages" yes
        asyncBash_add_msg_below_ps1 "Possible values for $arg:" 
        show_relative_command_number_args $((cmdnumber - arg))
    elif (( cmdnumber == arg )); then
        dest=!#:0 
    else
        dest=$arg
        asyncBash_add_msg_below_ps1 "error history line $dest not found" 
    fi

    local write="${cmda[@]:0:$idx} $dest"
    #Substitute history line
    asyncBash_substitute_command_line "$write"
}


clean_substring_search() {
    asyncBash_clean_screen_msgs "Search substring was reset"
    #reset substring history search
    currentSearchArg=
    currentSearchIdx=0
}

#Search forward/backward for a substring in the history and return it to the command line
#It doesn't work right with arguments with spaces "dir with spaces"
#More than enough for me use case
search_substring_history(){
    [[ -z $asyncBash_current_cmd_line ]] && return
    bind -x '"\C-q": clean_substring_search'
    local way=$1
    local -a cmda=($asyncBash_current_cmd_line)
    #get last argument index
    local idx=$((${#cmda[@]}-1))
    local arg=
    local write=
    local end=0
    local found=0

    #not active search
    if [[ -z $currentSearchArg ]]; then
        #delete all previous messages and clean the screen
        asyncBash_del_msg_below_ps1 -1
        #reset 
        arrayhistory=()
        #get last argument
        arg=${cmda[$idx]}
        #echo "Indexing."
        #load search in arrayhistory
        while IFS= read -r lines;
        do
            readarray -t line <<<"$lines"
            #command contains 
            if [[ ${line[@]} == *$arg* ]]; then
                #command arg contains
                for elem in ${line[@]}; do 
                    if [[ $elem == *$arg* ]]; then
                        #unique elements, so you must do "exhaustive" 
                        for hay in ${!arrayhistory[@]} ; do
                            [[ ${arrayhistory[$hay]} == $elem ]] && found=1
                        done
                        ((!found)) && arrayhistory+=("$elem") 
                        found=0
                    fi
                done
            fi
        done < <(fc -nlr 1)

        asyncBash_add_msg_below_ps1  "Enter Control-q to reset search" yes
        #and set the global values
        currentSearchArg=$arg
        currentSearchIdx=0
    else #active search
        if [[ $way == backward ]];then
            if (( currentSearchIdx < $(( ${#arrayhistory[@]}-1 )) )); then
                ((currentSearchIdx++))
            else
            end=1
        fi
    else #forward
        if (( currentSearchIdx > 0 )); then
            ((currentSearchIdx--))
        else
        end=1
    fi
fi
    fi

    if ((!end)); then
        arg=${arrayhistory[$currentSearchIdx]}
        write="${cmda[@]:0:$idx} $arg"
    else
        write="${cmda[@]} "
    fi
    #Substitute history line
    asyncBash_substitute_command_line "$write"
}


