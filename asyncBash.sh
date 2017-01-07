# vim: set filetype=sh :
# asyncBash
# Copyright © 2016 liloman

################################
#  asyncBash global variables  #
################################

#current command line with the '#' stripped out
declare -g asyncBash_current_cmd_line=
#Arrays whith messages to show below PS1
declare -gA asyncBash_msgs_below_ps1
declare -ga asyncBash_msgs_below_ps1_order
#flag for pending messages below the PS1
declare -gi asyncBash_msgs_in_queue=0
#current asyncBash_historyid = "current" history number
declare -gi asyncBash_historyid=0
#current PS1 row
declare -gi asyncBash_consolerow=0
#number of lines above your PS1 (mine =2 ;) )
declare -gi asyncBash_prompt_command_lines=0
#flag to indicate a launched asyncBash command
declare -gi asyncBash_flag_on=0
#Get current number of lines/rows of the terminal
declare -gi asyncBash_terminal_rows=$(tput lines)
#Number of empty lines in a msg
declare -gi asyncBash_empty_lines=0
#Array with temporal keybindings 
declare -ga asyncBash_temporal_keybindings=()

############
#  output  #
############

#Array with the output messages
declare -ga asyncBash_output_text
#Array with the associated values of the output
declare -ga asyncBash_output_value
#Current output index position
declare -gi asyncBash_output_index=0

###########
#  input  #
###########

#Current asyncBash function name
declare -g  asyncBash_input_functionname=
#Current argument processed by the asyncBash function
declare -g  asyncBash_input_argument=


########################################
#  USER DEFINED FUNCTIONS DECLARATION  #
########################################

#Defined by user do not edit this, they 
#are mean to be overwritten by the user

#Execute this when not an asyncBash call
asyncBash:Before_Not_AsyncBash_Call() { :; }
#Execute this when an asyncBash call
asyncBash:Before_AsyncBash_Call() { :; }
#Execute this after any command
asyncBash:After_Any_Call()   { :; }


##############################
#  asyncBash Core Functions  #
##############################



#Hook function to work with asyncBash
#Call it on your PROMPT_COMMAND
asyncBash:Hook() {
    #If not a asyncBash call
    if ((!asyncBash_flag_on)); then
        #save current console row to restore it 
        asyncBash:Save_Current_Row
        #clean possible previous msgs
        asyncBash:Clean_Screen_Below_PS1
        #Delete temporal keybindings
        asyncBash:Remove_Temporal_Keybindings
        #Call user defined cleanning function
        asyncBash:Before_Not_AsyncBash_Call
    else #it's in a asyncBash call so restore prompt position
        asyncBash:Restore_Row_position
        #Call user preparation function
        asyncBash:Before_AsyncBash_Call
        asyncBash_empty_lines=0
    fi

    #set asyncBash envirovment
    asyncBash:Set_Env
    #Call user on hook function
    asyncBash:After_Any_Call
    #reset asyncBash status flag
    asyncBash_flag_on=0
}


#set asyncBash_historyid,asyncBash_current_cmd_line and reset asyncBash_flag_on
asyncBash:Set_Env() {
    local last=($(HISTTIMEFORMAT=; history 1))
    #set global asyncBash_historyid
    asyncBash_historyid=${last[0]}
    #remove id
    local actual=${last[@]:1}
    #eliminate till first #
    local cmd=${actual#*#}
    #set global variable
    asyncBash_current_cmd_line=$cmd
}

#Set internal key bindings and launch user ones
# after a bind -x not possible to execute a bind without -x ¿?
asyncBash:Set_Keys() {
    #Start function
    #C-gs0 must be executed first!
    bind    '"\C-gs": "\C-gs0\e#"'
    bind -x '"\C-gs0": "asyncBash_flag_on=1"'

    #End function
    bind    '"\C-ge": "\eki\C-ge1\C-ge2"'
    #delete just rewrote history line 
    bind -x '"\C-ge1": " ((asyncBash_historyid >0)) && history -d $asyncBash_historyid"'
    #show the msgs in the queue below the PS1
    bind -x '"\C-ge2": "asyncBash:Show_Msg_Below_PS1"'

    #Load vi insert mode user keybindings
    bind -f "${BASH_SOURCE%/*}/asyncBash.inputrc"
}

#Delete temporal keybindings
asyncBash:Remove_Temporal_Keybindings() {
    local -i i=0
    for key in "${asyncBash_temporal_keybindings[@]}"; do
        bind -r $key
        bind -r "\C-gt$i"
        ((i++))
    done
    asyncBash_temporal_keybindings=()
}

#Create a keybind during the duration of the asyncBash
# $1: keybind
# $2: shell function to call
# $3: 1º shell function argument
asyncBash:Create_Temporal_Keybinding() {
    local keybind=$1
    local fun=$2
    local arg=$3

    #fun and arg need to be separated with that space ¿?
    #i can't get it to work with just 1 argument (must be something related to expansion when spaces)
    bind -x <<< echo '"\C-gt'${#asyncBash_temporal_keybindings[@]}'": '$fun' '$arg''
    bind <<< echo "\"$keybind\": \"\C-gs\C-gt${#asyncBash_temporal_keybindings[@]}\C-ge\C-e\"" 
    asyncBash_temporal_keybindings+=("$keybind")
}

#Substitute last command with $1
asyncBash:Substitute_Command_Line() {
    if ((asyncBash_historyid>0)); then
        #remove last history entry 
        history -d $asyncBash_historyid
        #append to history line
        history -s "$@"
    fi
}


#restore saved consolerow from asyncBash_save_current_row in ps1
#it's executed before an asyncBash call to put the cursor in just above the "old"
# prompt to let bash override it again making the ilusion of no change :)
asyncBash:Restore_Row_position() {
    #set current number of lines of the terminal
    asyncBash_terminal_rows=$(tput lines)
    #calculate final row
    local -i current_row=$(($asyncBash_consolerow)) 

    if (( $current_row < $asyncBash_terminal_rows )); then
        #sleep 2 # uncomment for debug ;)
        # go up prompt command lines + cli line
        tput cup $(($asyncBash_consolerow - $asyncBash_prompt_command_lines - 1)) 0
        #sleep 2 # uncomment for debug ;)
    else #Special case when the prompt is in the last row (bottom of the terminal)
        #if in bottom and no previous command (but asyncBash call or empty line)
        # 2 use cases: prev or no prev command
        #sleep 4 # uncomment for debug ;)
        if (( $current_row == $asyncBash_terminal_rows )); then
            # go up prompt command lines + cli line + auto scroll (cause bottom)
            tput cup $(($asyncBash_consolerow - $asyncBash_prompt_command_lines - 2)) 0
        else # the user executed a previous command so the real row could be wrong cause asyncBash_prompt_command_lines
            local -i diff=$((current_row - asyncBash_terminal_rows))
            # go up prompt command lines + cli line + auto scroll (cause bottom) + new lines of output
            tput cup $(($asyncBash_consolerow - $asyncBash_prompt_command_lines - 2 - $diff)) 0
        fi
        #sleep 4 # uncomment for debug ;)
    fi
    #clean screen below PS1
    tput ed
}


#get current PS1 row to restore it after ctl-g functions
asyncBash:Save_Current_Row() {
    local COL
    local ROW
    IFS=';' read -sdR -p $'\E[6n' ROW COL
    asyncBash_consolerow="${ROW#*[}"
    #get the real line number counting with the prompt command lines :)
    ((asyncBash_consolerow+=$asyncBash_prompt_command_lines))
}


#add a msg to show it below the PS1
#$2 to indicate if must be fixed until command execution
#the msg line is cut to the current column number cause when displayed
#the terminal wrapping is disabled temporalily due usability mesures
asyncBash:Add_Msg_Below_PS1() {
    local msg=${1:-empty}
    local fix=${2:-no}
    #number of columns of the terminal
    local -i step=$(tput cols)
    local -i end=${#msg}
    local msg_cut=""
    
    for start in $(eval echo {0..$end..$step}); do
        #cut 
        msg_cut=${msg:$start:$step}
        #if no msg left default to empty
        [[ -z $msg_cut ]] && msg_cut=empty
        asyncBash_msgs_below_ps1_order+=("${msg_cut}")
        asyncBash_msgs_below_ps1["${msg_cut}"]=$fix  
        asyncBash_msgs_in_queue=1
    done
    #increment empty lines to know the total lines of the output (emptied + filled)
    [[ $msg == empty ]] && ((asyncBash_empty_lines++))
}

#delete a/all msg to not show it again below the PS1
#pass 0 to delete all and clean screen below PS1
#pass 1 to delete all but fixed (workaround due bug in unset)
asyncBash:Del_Messages_Below_PS1() {
    local -i arg=$1
    local clean=${2:-yes}
    local msg= 
    local -a temp=()

    if ((arg)); then
        ## bug: needs reporting
        ## crash/dont remove if msg contains any ',^,\...
        #unset -v asyncBash_msgs_below_ps1["${msg}"] 
        # works
        #unset -v asyncBash_msgs_below_ps1_order[$id]

        for key in "${!asyncBash_msgs_below_ps1[@]}"; do
            [[ ${asyncBash_msgs_below_ps1["$key"]}  == yes ]] && temp+=("$key")
        done

        #reset
        asyncBash_msgs_below_ps1_order=()
        asyncBash_msgs_below_ps1=()
        asyncBash_msgs_in_queue=0
        #add fixed messages
        for msg in "${temp[@]}" ; do
            asyncBash:Add_Msg_Below_PS1 "$msg" yes
        done
    else
        asyncBash_msgs_below_ps1_order=()
        asyncBash_msgs_below_ps1=()
        asyncBash_msgs_in_queue=0
        #clean screen below PS1
        [[ $clean == yes ]] && tput ed
    fi
}

#Show messages below the PS1
asyncBash:Show_Msg_Below_PS1() {
    local fix=
    local msg=
    local -i found_fixed=0
    local -i id=0
    local pager_output=

    #if messages in queue
    if ((asyncBash_msgs_in_queue)); then 
        #disable glob expansion
        set -f
        #disable line wrapping (to control real $lines_displayed)
        tput rmam
        #leave an empty line below the ps1
        tput cud1
        #number of messages displayed below ps1
        local -i lines_displayed=$(( ${#asyncBash_msgs_below_ps1[@]} + 1 )) #add the leaved empty line (see above)
        #calculate final row
        local -i final_row=$(($asyncBash_consolerow + $lines_displayed)) 
        # lines displayed + cli + prompt + possible ctrl-q message + empty lines
        local -i real_output=$(( $lines_displayed + 1 + $asyncBash_prompt_command_lines + 1 + $asyncBash_empty_lines))


        #for each message
        for id in ${!asyncBash_msgs_below_ps1_order[@]}; do
            #get msg
            msg=${asyncBash_msgs_below_ps1_order[$id]}
            #temporal or static
            fix=${asyncBash_msgs_below_ps1["$msg"]}
            #if temporal not show again (delete it)
            #otherwise dont delete it and mark messages 
            # in the queue for the next possible call
            [[ $fix == yes ]] && found_fixed=1
            [[ $msg == empty ]] && msg=
            #print the msg (should the msg be cleaned after x seconds?)
            if (( $real_output > $asyncBash_terminal_rows )); then
                pager_output+="$msg\n"
            else
                #force scroll
                tput cud1
                #clean the line 
                tput el
                #echo without interpret
                echo -nE "${msg}"
            fi
        done

        if (( $real_output > $asyncBash_terminal_rows )); then
            # pipe and not redirect to escape characters in bash before
            [[ -z $PAGER ]] && PAGER=less
            echo -e $pager_output | $PAGER
            #go up 1 line
            tput cuu1
        else # no pager needed :)
            #leave the cursor just 1 line above the cli (no prompt_command execution at this time)
            local -i old_row=$(($asyncBash_consolerow - 1)) 

            # the output doesn't need scrolling put the cursor where it was before the output
            if (( $final_row <= $asyncBash_terminal_rows )); then
                #sleep 2 # (uncomment to debug) ;)
                tput cup $old_row 0
                #sleep 2 # (uncomment to debug) ;)
            else # the terminal needs to do scrolling to show the output
                #sleep 2 # (uncomment to debug) ;)
                local -i diff=$(( $final_row - $asyncBash_terminal_rows ))
                tput cup $(($old_row - $diff)) 0
                #adjust real position for chained calls
                ((asyncBash_consolerow-=diff))
                #sleep 2 # (uncomment to debug) ;)
            fi
        fi
        #set flag queue
        asyncBash_msgs_in_queue=$found_fixed
        #delete all or not fixed messages without cleaning screen
        asyncBash:Del_Messages_Below_PS1 $found_fixed no
        #enable line wrapping
        tput smam
        #enable glob expansion
        set +f
    fi
}


#Clean screen messages,reset env variables showing a message on finish if wanted
asyncBash:Clean_Screen_Below_PS1() {
    local msg=$1
    #delete all messages arrays and clean screen 
    asyncBash:Del_Messages_Below_PS1 0

    if [[ -n $msg ]]; then
        asyncBash:Add_Msg_Below_PS1 "$msg"
        asyncBash:Show_Msg_Below_PS1
    fi
}

#Load the shortkeys and hoot it to the PS1
asyncBash:Load() {
    #Load the keybindings
    asyncBash:Set_Keys 
    #Load the user functions
    . "${BASH_SOURCE%/*}/my_fun.sh"
    #Hook asyncBash to PROMPT_COMMAND
    PROMPT_COMMAND+=";asyncBash:Hook"
}


#Load it
asyncBash:Load
