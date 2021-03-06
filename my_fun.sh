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



##################
#  STATIC BINDS  #
##################

#<warning>
#It's important to quote all single parameters if you try to pass "fun arg" 
#it won't work and some keybindings will be remove from your keyboard so be careful
#</warning>

# Use Ctrl + v to see the keybindings (^[ is \e)
#\e is Alt/M-/Esc/... for keybindings (Escape)
#\C- is Control 

#Bind to insert relative command  number
#positive number for current session
# <=0 for older sessions ;)
asyncBash:Create_Static_Keybinding "\C-h" "insert_relative_command_number"

# Search for a substring *argument* into history 
# c-n dynamic-complete-history on steroids 
# backward
asyncBash:Create_Static_Keybinding "\C-s" "search_substring_history" "backward"
# # # forward
asyncBash:Create_Static_Keybinding "\C-r" "search_substring_history" "forward"

# alt + h + f: Show hints for first command
asyncBash:Create_Static_Keybinding "\ehf" "show_command_hints" "0"

#alt + h + l: Show hints for last command
asyncBash:Create_Static_Keybinding "\ehl" "show_command_hints" "1"

#alt + e + f:  Create/Edit hints for first
asyncBash:Create_Static_Keybinding "\eel" "edit_command_hint" "0"

#alt + e + l: Create/Edit hints for last command
asyncBash:Create_Static_Keybinding "\eel" "edit_command_hint" "1"

#alt + r: Execute command line without moving
asyncBash:Create_Static_Keybinding "\er" "run_current_cli"

########################
#  User defined hooks  #
########################

#Execute this when not an asyncBash call
asyncBash:Before_Not_AsyncBash_Call() { :; }

#Execute this when in an asyncBash call
asyncBash:Before_AsyncBash_Call() { :; }

#Execute this after any command
asyncBash:Before_Any_Call()   { 
    #set cmdnumber 
    set_cmd_number
}


###############
#  Functions  #
###############

#Move the selection one line up
select_list_up() {
  local -a position=()
  local -i row=0
  local msg=
  local next=
  local -a cmda=($asyncBash_current_cmd_line)

  #if it's possible to move up
  if (( $asyncBash_output_index_list > 0 )); then
      ((asyncBash_output_index_list--))

      position=${asyncBash_output_position[$asyncBash_output_index_list]}
      row=${position[0]}
      msg=${asyncBash_output_text[$asyncBash_output_index_list]}
      tput sc

     if (( $asyncBash_output_index_list +1 < ${#asyncBash_output_position[@]} )); then
          next=${asyncBash_output_text[$asyncBash_output_index_list+1]}
          tput vpa $((row+1))
          tput el 
          echo -E "$next"
      fi

      tput vpa $row
      tput el
      tput el
      echo -e "\033[44m$msg\033[0m index:$asyncBash_output_index_list"
      tput rc

      #Substitute history line
      asyncBash:Substitute_Command_Line "${cmda[@]:0:$((${#cmda[@]}-1))} $msg"
  else
      asyncBash:Substitute_Command_Line "${asyncBash_current_cmd_line}"

  fi
}

#Move the selection one line down
select_list_down() {
  local -a position=()
  local -i row=0
  local msg=
  local prev=
  local -i pos=$asyncBash_output_index_list
  local -a cmda=($asyncBash_current_cmd_line)

  #if it's possible to move down
  if (( $asyncBash_output_index_list < ${#asyncBash_output_position[@]}-1 )); then
      ((asyncBash_output_index_list++))

      position=${asyncBash_output_position[$asyncBash_output_index_list]}
      msg=${asyncBash_output_text[$asyncBash_output_index_list]}
      row=${position[0]}
      tput sc

      if (( $asyncBash_output_index_list -1 >= 0 )); then
          prev=${asyncBash_output_text[$asyncBash_output_index_list-1]}
          tput vpa $((row-1))
          tput el 
          echo -E "$prev"
      fi

      tput vpa $row
      tput el 
      echo -e "\033[44m$msg\033[0m index:$asyncBash_output_index_list"
      tput rc


      #Substitute history line
      if (( $pos == -1 )); then
          asyncBash:Substitute_Command_Line "${asyncBash_current_cmd_line} $msg"
      else
          asyncBash:Substitute_Command_Line "${cmda[@]:0:$((${#cmda[@]}-1))} $msg"

      fi
  else
          asyncBash:Substitute_Command_Line "${asyncBash_current_cmd_line}"
  fi

    
}

#Execute current command and show output below the ps1
# with error in red
# execute multiple commands
run_current_cli() {
    [[ -z $asyncBash_current_cmd_line ]] && return

    #Clean possible previous asyncBash calls
    asyncBash:Clean_Screen_Below_PS1
    local line=
    local com=($asyncBash_current_cmd_line)

    # #alt + down arrow
    asyncBash:Create_Temporal_Keybinding "no" "\e[1;3B" "select_list_down"
    # #alt + up arrow
    asyncBash:Create_Temporal_Keybinding "no" "\e[1;3A" "select_list_up"


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
    asyncBash:Substitute_Command_Line "${cmda[@]}"
}


#Autocomplete
autocomplete_hints() {
    [[ -z $asyncBash_current_cmd_line ]] && return

    local -a cmda=($asyncBash_current_cmd_line)
    #modify last argument = autocomplete :)
    cmda[-1]=${asyncBash_output_value[$asyncBash_output_index]}

    #cycle between results
    if (( $asyncBash_output_index + 1 >= ${#asyncBash_output_value[@]} )); then
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
        asyncBash:Create_Temporal_Keybinding "no" "\ea" "autocomplete_hints"

        #Reset possibles prev searches
        asyncBash_output_value=()
        asyncBash_output_index=-1

        for file in $(shopt -s dotglob;echo "$path/$cmd"*.txt); do
            file=${file##*/}; file=${file::-4}
            [[ $file == $cmd'*' ]] && break #no luck
            ((i)) || {
            if [[ -n $asyncBash_current_cmd_line ]]; then 
                asyncBash:Add_Msg_Below_PS1 "Exact match not found. Possible values are:" yes
            else
                asyncBash:Add_Msg_Below_PS1 "Listing all hints:" yes 
            fi
        }
            ((i++))
            asyncBash:Add_Msg_Below_PS1 "$i)${file}" yes
            asyncBash_output_value+=("$file")
        done
    fi

    #Substitute history line
    [[ -z $asyncBash_current_cmd_line ]] && cmda=("")
    asyncBash:Substitute_Command_Line "${cmda[@]}"
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


#Reset substring history search
reset_substring_search() {
    asyncBash:Clean_Screen_Below_PS1 "Search substring was reset"
    #reset substring history search
    asyncBash_input_argument=
    asyncBash_associate_values=()
    asyncBash_associate_index=0
}

#For gg substring history search keybinding
search_substring_history_first() { 
    asyncBash_associate_index=$(( ${#asyncBash_associate_values[@]} / 2 ))
    search_substring_history backward first
}

#For G substring history search keybinding
search_substring_history_last() { 
    asyncBash_associate_index=-1
    search_substring_history forward last
}

#Search forward/backward for a substring in the history and return it to the command line
#It doesn't work right with arguments with spaces "dir with spaces"
#More than enough for me use case
search_substring_history() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    bind -x '"\C-q": reset_substring_search'
    local way=$1
    local move=$2
    local -a cmda=($asyncBash_current_cmd_line)
    #get last argument index
    local idx=$((${#cmda[@]}-1))
    local arg=
    local write=
    local end=0
    local found=0
    local mid=0

    # For each result
    show_extended_info() {
        mid=$(( ${#asyncBash_associate_values[@]} / 2 ))
        local msg1="Position:[$((asyncBash_associate_index+1))/$mid] --> " 
        local hid=${asyncBash_associate_values[historyid$asyncBash_associate_index]}
        local msg2=" Historyid:$hid" 
        # unfortunetly no other than the n00b way
        local history_line=$(HISTTIMEFORMAT='%c|' history | grep "^[[:space:]]*$hid ") 
        local temp=(${history_line%|*})
        local date=${temp[@]:1}
        local hcmd=${history_line##*|}
        asyncBash:Add_Msg_Below_PS1 "$msg1 $msg2 Date:$date"
        asyncBash:Add_Msg_Below_PS1 "Complete command line:${hcmd}"
    }

    #not active search
    if [[ -z $asyncBash_input_argument ]]; then
        #delete all previous messages and clean the screen
        asyncBash:Del_Messages_Below_PS1 0
        #get last argument
        arg=${cmda[$idx]}
        #reset just needed
        asyncBash_associate_values=()
        asyncBash_associate_index=0
        #and set the global values
        asyncBash_input_argument=$arg

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
                        for index in $(eval echo {0..$asyncBash_associate_index}); do
                            if [[ ${asyncBash_associate_values[match$index]} == $elem ]]; then
                                found=1 
                                break
                            fi
                        done
                        if ((!found)); then
                            #for each match 2 new values in the associative array
                            # match for the argument
                            # historyid for the historyid :)
                            asyncBash_associate_values[match$asyncBash_associate_index]=$elem
                            asyncBash_associate_values[historyid$asyncBash_associate_index]=${line[0]}
                            ((asyncBash_associate_index++))
                        fi
                        found=0
                    fi
                done
            fi
        done < <(fc -lr 1) # histfilesize must be <= histsize otherwise "out of range"
        #Clean indexing msg
        tput hpa 0 #move to column 0
        tput el #clean the from cursor to end of line

        if ((!$asyncBash_associate_index)); then
            asyncBash:Add_Msg_Below_PS1  "Enter Control-q to reset your search ($arg)" yes
            asyncBash:Add_Msg_Below_PS1  "Nothing found!.Try harder :)"
        else
            asyncBash:Add_Msg_Below_PS1  "Enter Control-q to reset your search ($arg)" yes
            asyncBash:Add_Msg_Below_PS1  "Enter gg to go to first result, G to go to the last result" yes
            asyncBash:Create_Temporal_Keybinding "yes" "G" "search_substring_history_first"
            asyncBash:Create_Temporal_Keybinding "yes" "gg" "search_substring_history_last"
            asyncBash_associate_index=0
            show_extended_info
        fi
    else #active search order by time, so backward is further in time (ctl + r)
        if [[ $way == forward ]];then
               #it holds two elements (msg,historyid) for each result
                mid=$(( ${#asyncBash_associate_values[@]} / 2 -1))
                if (( asyncBash_associate_index < $mid ));
                then
                    ((asyncBash_associate_index++))
                else
                    if [[ -n $move ]]; then
                        cmda[-1]=${asyncBash_associate_values[match$asyncBash_associate_index]}
                    fi
                    end=1
                fi
        else #forward search
                if (( asyncBash_associate_index > 0 )); then
                    ((asyncBash_associate_index--))
                else
                    if [[ -n $move ]]; then
                        cmda[-1]=${asyncBash_associate_values[match$asyncBash_associate_index]}
                    fi
                    end=1
                fi
        fi #end  forward search

       #Show extended info
       if (( ${#asyncBash_associate_values[@]} )); then
           show_extended_info
       fi
   fi # end active search


    if ((!end)); then
        arg=${asyncBash_associate_values[match$asyncBash_associate_index]}
        write="${cmda[@]:0:$idx} $arg"
    else
        write="${cmda[@]} "
    fi
    #Substitute history line
    asyncBash:Substitute_Command_Line "$write"
}


