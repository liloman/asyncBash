# vim: set filetype=sh :
# asyncBash
# Copyright © 2016 liloman

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

#Defined by user
#Execute this when not an asyncBash call
asyncBash_after_out() { :; }
#Execute this when an asyncBash call
asyncBash_before_in() { :; }
#Execute this after any command
asyncBash_on_hook()   { :; }

#Hook function to work with asyncBash
#Call it on your PS1
asyncBash_hook() {
    #If not a asyncBash call
    if ((!asyncBash_flag_on)); then
        #save current console row to restore it 
        asyncBash_save_current_row
        #clean possible previous msgs
        asyncBash_clean_screen_msgs
        #Call user defined cleanning function
        asyncBash_after_out
    else #it's in a asyncBash call so restore prompt position
        asyncBash_restore_row_position
        #Call user preparation function
        asyncBash_before_in
    fi

    #set asyncBash envirovment
    asyncBash_set_env
    #Call user on hook function
    asyncBash_on_hook
    #reset asyncBash status flag
    asyncBash_flag_on=0
}


#set asyncBash_historyid,asyncBash_current_cmd_line and reset asyncBash_flag_on
asyncBash_set_env() {
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
asyncBash_set_keys() {
    #Start function
    #C-gs0 must be executed first!
    bind    '"\C-gs": "\C-gs0\e#"'
    bind -x '"\C-gs0": "asyncBash_flag_on=1"'

    #End function
    bind    '"\C-ge": "\eki\C-ge1\C-ge2"'
    #delete just rewrote history line 
    bind -x '"\C-ge1": "history -d $asyncBash_historyid"'
    #show the msgs in the queue below the PS1
    bind -x '"\C-ge2": "asyncBash_show_msgs_below_ps1"'
}


#Substitute last command with $1
asyncBash_substitute_command_line() {
    #remove last history entry 
    history -d $asyncBash_historyid
    #append to history line
    history -s "$@"
}


#restore saved consolerow from asyncBash_save_current_row in ps1
asyncBash_restore_row_position() {
    #substract prompt_command lines
    tput cup $((asyncBash_consolerow+1-asyncBash_prompt_command_lines)) 0
    #clean screen below PS1
    tput ed
}


#get current PS1 row to restore it after ctl-g functions
asyncBash_save_current_row() {
    local COL
    local ROW
    IFS=';' read -sdR -p $'\E[6n' ROW COL
    asyncBash_consolerow="${ROW#*[}"
}


#add a msg to show it below the PS1
#$2 to indicate if must be fixed until command execution
asyncBash_add_msg_below_ps1() {
    local msg=$1
    local fix=${2:-no}
    asyncBash_msgs_below_ps1_order+=("$msg")
    asyncBash_msgs_below_ps1[$msg]=$fix
    asyncBash_msgs_in_queue=1
}

#delete a/all msg to not show it again below the PS1
#pass -1 to delete all and clean screen below PS1
asyncBash_del_msg_below_ps1() {
    local -i id=$1
    local msg=
    if ((id>=0)); then
        msg=${asyncBash_msgs_below_ps1_order[$id]}
        unset -v asyncBash_msgs_below_ps1_order[$id]
        unset -v asyncBash_msgs_below_ps1["$msg"] 
    else
        asyncBash_msgs_below_ps1_order=()
        asyncBash_msgs_below_ps1=()
        asyncBash_msgs_in_queue=0
        #clean screen below PS1
        tput ed
    fi
}

#Show messages below the PS1
asyncBash_show_msgs_below_ps1() {
    local fix=
    local msg=
    local -i found=0
    local -i id=0

    #if messages in queue
    if ((asyncBash_msgs_in_queue)); then 
        #move cursor 1 line below PS1
        tput cup $((asyncBash_consolerow+asyncBash_prompt_command_lines)) 0
        #for each message
        for id in ${!asyncBash_msgs_below_ps1_order[@]}; do
            #get msg
            msg=${asyncBash_msgs_below_ps1_order[$id]}
            #temporal or static
            fix=${asyncBash_msgs_below_ps1["$msg"]}
            #if temporal not show again
            #otherwise mark messages in the queue for the next possible call
            [[ $fix == no ]] && asyncBash_del_msg_below_ps1 $id || found=1
            #clean the line 
            tput el
            #print the msg (should the msg be cleaned after x seconds?)
            echo $msg 
        done
        #restore cursor
        tput cup $((asyncBash_consolerow+asyncBash_prompt_command_lines-1)) 0
        #set flag queue
        asyncBash_msgs_in_queue=$found
    fi
}


#Clean screen messages,reset env variables showing a message on finish if wanted
asyncBash_clean_screen_msgs() {
    local msg=$1
    #delete all messages arrays and clean screen 
    asyncBash_del_msg_below_ps1 -1
    #unbind Ctrl-q 
    bind -r "\C-q"
    if [[ -n $msg ]]; then
        asyncBash_add_msg_below_ps1 "$msg"
        asyncBash_show_msgs_below_ps1
    fi
}

#Load the keybindings
asyncBash_set_keys 
#And load the user functions
. "${BASH_SOURCE%/*}/my_fun.sh"
