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



#################################
#  BINDS for asyncBash.inputrc  #
#################################

#Bind to insert relative command  number
#positive number for current session
# <=0 for older sessions ;)
bind -x '"\C-gb0":insert_relative_command_number'

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

#Execute current command without moving
bind -x '"\C-gb7": run_current_cli'


########################
#  User defined hooks  #
########################

#Execute this when not an asyncBash call
asyncBash:Before_Not_AsyncBash_Call() { :; }

#Execute this when in an asyncBash call
asyncBash:Before_AsyncBash_Call() { :; }

#Execute this after any command
asyncBash:After_Any_Call()   { 
    #set cmdnumber 
    set_cmd_number
}


###############
#  Functions  #
###############

#Execute current command and show output below the ps1
# with error in red
# execute multiple commands
run_current_cli() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    asyncBash_input_functionname=$FUNCNAME
    #Clean possible previous asyncBash calls
    asyncBash:Clean_Screen_Below_PS1
    local line=
    local com=($asyncBash_current_cmd_line)

    while IFS= read -r line
    do
        asyncBash:Add_Msg_Below_PS1 "$line"
    # show errors in red
    done < <("${com[@]}" 2> >(while read line; do echo -e "\e[01;31m$line\e[0m" ; done))

    #Substitute history line
    asyncBash:Substitute_Command_Line "${asyncBash_current_cmd_line}"
}


#Display a cheatsheet for the current command
#from ~/.local/share/asyncBash/hints
edit_command_hint() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    asyncBash_input_functionname=$FUNCNAME
    #Clean possible previous asyncBash calls
    asyncBash:Clean_Screen_Below_PS1
    local -a cmda=($asyncBash_current_cmd_line)
    local last=$1
    local cmd=
    (( $last )) && cmd=${cmda[-1]}  || cmd=${cmda[0]}
    local file="$HOME/.local/share/asyncBash/hints/$cmd.txt"

    if [[ -e $file  ]]; then
        #show a legend with the possible arguments
        asyncBash:Add_Msg_Below_PS1 "editting the hint with $EDITOR" 
    else
        asyncBash:Add_Msg_Below_PS1 "created a new file and editting it with $EDITOR" 
    fi
    $EDITOR $file
    #Substitute history line
    asyncBash:Substitute_Command_Line "${cmda[@]:-1}"
}


#Autocomplete
autocomplete_hints() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    asyncBash_input_functionname=$FUNCNAME

    local -a cmda=($asyncBash_current_cmd_line)
    #modify last argument = autocomplete :)
    cmda[-1]=${asyncBash_output_text[$asyncBash_output_index]}

    #cycle between results
    if (( $asyncBash_output_index + 1 >= ${#asyncBash_output_text[@]} )); then
        asyncBash_output_index=0
    else
        (( asyncBash_output_index++ ))
    fi

    #Substitute history line
    asyncBash:Substitute_Command_Line "${cmda[@]}"
}

#Display a cheatsheet for the current command
#from ~/.local/share/asyncBash/hints
# if empty line then show all hints 
# if a exact match is not found then show relatives
show_command_hints() {
    asyncBash_input_functionname=$FUNCNAME
    #Clean possible previous asyncBash calls
    asyncBash:Clean_Screen_Below_PS1
    local -a cmda=($asyncBash_current_cmd_line)
    local last=$1
    local cmd=
    local keybin="Alt + e"
    if (( $last )); then
        [[ -n $asyncBash_current_cmd_line ]] && cmd=${cmda[-1]} 
        keybin=$keybin" + l"
    else
        [[ -n $asyncBash_current_cmd_line ]] && cmd=${cmda[0]} 
        keybin=$keybin" + f"
    fi
    local path="$HOME/.local/share/asyncBash/hints"
    local file="$path/$cmd.txt"
    local i=0

    #create it if it doesn't exist
    [[ ! -e $path ]] && mkdir -p $path

    #special argument to list all the hints
    if [[ -e $file  ]]; then #exact match
        bind -x '"\C-q": asyncBash:Clean_Screen_Below_PS1'
        asyncBash:Add_Msg_Below_PS1 "Enter Control-q to clean screen messages" yes
        while IFS= read -r line; do 
            asyncBash:Add_Msg_Below_PS1 "$line"
        done < $file
    else #don't found suggest similar hints
        bind -x '"\C-q": asyncBash:Clean_Screen_Below_PS1'
        asyncBash:Add_Msg_Below_PS1 "Enter Control-q to clean screen messages" yes
        asyncBash:Add_Msg_Below_PS1 "You can created a new file or edit it with $EDITOR with $keybin"  yes
        asyncBash:Add_Msg_Below_PS1 "Enter Alt-a to autcomplete hints" yes
        asyncBash:Create_Temporal_Keybinding "\ea" "autocomplete_hints"

        #Reset possibles prev searches
        asyncBash_output_text=()
        asyncBash_output_index=-1

        for file in $(shopt -s dotglob;echo "$path/$cmd"*.txt); do
            file=${file##*/}; file=${file::-4}
            [[ $file == $cmd'*' ]] && break #no luck
            ((i)) || {
            if [[ -n $asyncBash_current_cmd_line ]]; then 
                asyncBash:Add_Msg_Below_PS1 "Exact match not found. Possible values are:"yes
            else
                asyncBash:Add_Msg_Below_PS1 "Listing all hints:" yes 
            fi
        }
            ((i++))
            asyncBash:Add_Msg_Below_PS1 "$i)${file}" yes
            asyncBash_output_text+=("$file")
        done
    fi

    #Substitute history line
    [[ -z $asyncBash_current_cmd_line ]] && cmda=("")
    asyncBash:Substitute_Command_Line "${cmda[@]:-1}"
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
    asyncBash_input_functionname=$FUNCNAME
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

        asyncBash:Add_Msg_Below_PS1 "$msg  $args"
    }
    #Clean possible previous asyncBash calls
    asyncBash:Clean_Screen_Below_PS1
    local -a cmda=($asyncBash_current_cmd_line)
    #get last argument index
    local idx=$((${#cmda[@]}-1))
    #get last argument
    local arg=${cmda[$idx]}
    local dest=

    if [[ ! $arg =~ ^-?[0-9]+([0-9]+)?$ ]]; then
        asyncBash:Add_Msg_Below_PS1 "error:$arg is not a number"
        #Substitute history line
        asyncBash:Substitute_Command_Line "${asyncBash_current_cmd_line}"
        return
    fi
    #substract the current command number with the destiny (last argument)
    #works with 0...-N to go before current session... :)
    if (( cmdnumber > arg )); then
        dest=!-$((cmdnumber - arg)): 
        #do not tamper with shopt -s histverify
        asyncBash:Add_Msg_Below_PS1 "empty" 
        #hook Ctrl-q to clean the messages without a msg
        bind -x '"\C-q": asyncBash:Clean_Screen_Below_PS1'
        #show a legend with the possible arguments
        asyncBash:Add_Msg_Below_PS1 "Enter Control-q to clean screen messages" yes
        asyncBash:Add_Msg_Below_PS1 "Possible values for $arg:" 
        show_relative_command_number_args $((cmdnumber - arg))
    elif (( cmdnumber == arg )); then
        dest=!#:0 
    else
        dest=$arg
        asyncBash:Add_Msg_Below_PS1 "error history line $dest not found" 
    fi

    local write="${cmda[@]:0:$idx} $dest"
    #Substitute history line
    asyncBash:Substitute_Command_Line "$write"
}


clean_substring_search() {
    asyncBash:Clean_Screen_Below_PS1 "Search substring was reset"
    #reset substring history search
    asyncBash_input_argument=
    asyncBash_output_index=-1
}

#For gg/G keybindings
search_substring_history_first() { 
    asyncBash_output_index=$((${#asyncBash_output_text[@]}-1))
    search_substring_history backward first
}

search_substring_history_last() { 
    asyncBash_output_index=0
    search_substring_history forward last
}

#Search forward/backward for a substring in the history and return it to the command line
#It doesn't work right with arguments with spaces "dir with spaces"
#More than enough for me use case
search_substring_history() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    asyncBash_input_functionname=$FUNCNAME
    bind -x '"\C-q": clean_substring_search'
    local way=$1
    local move=$2
    local -a cmda=($asyncBash_current_cmd_line)
    #get last argument index
    local idx=$((${#cmda[@]}-1))
    local arg=
    local write=
    local end=0
    local found=0

    #not active search
    if [[ -z $asyncBash_input_argument ]]; then
        #delete all previous messages and clean the screen
        asyncBash:Del_Messages_Below_PS1 0
        #reset 
        asyncBash_output_text=()
        asyncBash_output_value=()
        #get last argument
        arg=${cmda[$idx]}

        #Clean possible previous asyncBash calls
        asyncBash:Clean_Screen_Below_PS1
        echo -n "Indexing...Hold your horses"
        #load search in asyncBash_output_text
        while IFS= read -r lines;
        do
            #readarray doesn't work here? bug?
            read -a line <<<"${lines}"
            #command contains without the historyid
            if [[ ${line[@]:1} == *$arg* ]]; then
                #command arg contains
                for elem in ${line[@]:1}; do 
                    if [[ $elem == *$arg* ]]; then
                        #unique elements, so you must do "exhaustive" 
                        for hay in ${!asyncBash_output_text[@]} ; do
                            [[ ${asyncBash_output_text[$hay]} == $elem ]] && found=1
                        done
                        if ((!found)); then
                            asyncBash_output_text+=("$elem") 
                            asyncBash_output_value+=("${line[0]}") 
                        fi
                        found=0
                    fi
                done
            fi
        done < <(fc -lr 1) # histfilesize must be <= histsize otherwise "out of range"
        #Clean indexing msg
        tput hpa 0 #move to column 0
        tput el #clean the from cursor to end of line

        asyncBash:Add_Msg_Below_PS1  "Enter Control-q to reset your search ($arg)" yes
        asyncBash:Add_Msg_Below_PS1  "Enter gg to go to first result, G to go to the last result" yes
        asyncBash:Create_Temporal_Keybinding "G" "search_substring_history_first"
        asyncBash:Create_Temporal_Keybinding "gg" "search_substring_history_last"

        #and set the global values
        asyncBash_input_argument=$arg
        asyncBash_output_index=0
        if ((! ${#asyncBash_output_text[@]} )); then
            asyncBash:Add_Msg_Below_PS1  "Nothing found!.Try harder :)"
        fi
    else #active search order by time, so backward is further in time (ctl + r)
        if [[ $way == backward ]];then
                if (( asyncBash_output_index < $(( ${#asyncBash_output_text[@]}-1 )) )); then
                    ((asyncBash_output_index++))
                else
                    [[ -n $move ]] && { unset 'cmda[${#cmda[@]}-1]'; cmda+=("${asyncBash_output_text[$asyncBash_output_index]}"); }
                    end=1
                fi
        else #forward search
                if (( asyncBash_output_index > 0 )); then
                    ((asyncBash_output_index--))
                else
                    [[ -n $move ]] && { unset 'cmda[${#cmda[@]}-1]'; cmda+=("${asyncBash_output_text[$asyncBash_output_index]}"); }
                    end=1
                fi
        fi #end  forward search

   fi # end active search

   if (( ${#asyncBash_output_text[@]} )); then
       local msg1="Position:[$((asyncBash_output_index+1))/${#asyncBash_output_text[@]}] --> " 
       local msg2=" Historyid:${asyncBash_output_value[$asyncBash_output_index]}" 
       # unfortunetly no other than the n00b way
       local history_line=$(HISTTIMEFORMAT='%c|' history | grep "^[[:space:]]*${asyncBash_output_value[$asyncBash_output_index]} ") 
       local temp=(${history_line%|*})
       local date=${temp[@]:1}
       local hcmd=${history_line##*|}
       asyncBash:Add_Msg_Below_PS1 "$msg1 $msg2 Date:$date"
       asyncBash:Add_Msg_Below_PS1 "Complete command line:${hcmd}"
   fi

    if ((!end)); then
        arg=${asyncBash_output_text[$asyncBash_output_index]}
        write="${cmda[@]:0:$idx} $arg"
    else
        write="${cmda[@]} "
    fi
    #Substitute history line
    asyncBash:Substitute_Command_Line "$write"
}


