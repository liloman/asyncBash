# asyncBash

Make "async" calls from your bash prompt and get the results back in the same command line

#Install

```bash
cd ~/yourDir
git clone https://github.com/liloman/asyncBash
echo ". ~/yourDir/asyncBash/asyncBash.sh" >> ~/.bashrc
```

If you have like me a multiline prompt you can set this variable to your extra `PS1` lines, in my case:

```bash
asyncBash_prompt_command_lines=2 
```



#Tutorial

Let's make a simple keybinding that displays a hint below the `PS1` when the user presses `Alt-h`.
Suppose you want to display your custom hint/cheatsheet for the current command just below your `PS1`.

Your goal is something like:

```bash
$>journalctl -xr (pressed Alt-h)
 Press Ctl-q to clean the screen messages
 DATES
 -b: shows current boot
 --list-boots: list boots
 -b -N: previous N boot
 --since yesterday/09:00/"2015-01-10"
 --until yesterday/09:00/"2015-01-10"/"2015-01-10 17:15:00"
 PROCESS
 -u nginx.service
 _PID=444  / _UID=345 /  SYSLOG_IDENTIFIER=firejail / ...
```

##Make the generic binding for our function

You need to add this line to asyncBash.inputrc between the insert mode $if/$endif.
NOTE: \e is Alt/M- for keybindings

```bash
"\eh": "\C-gs\C-gb3\C-ge\C-e"
```
Pretty trivial:
1.C-gs to "transfer" the line to bash (start)
2.C-gb3 execute our bash function (we'll call it give_command_hint) when we'll process the current command line
3.C-ge to transfer back the modified command line (end)
4.Return to the last position of our command line in insert mode


##Bind Alt-h with the bash function

Above we have typed that C-gb3 will call our bash function (give_command_hint).
So we need to make that association.

All the user stuff will be added to my_fun.sh, search for BINDS and add:


```bash
###########
#  BINDS  #
###########
...
#Display a cheatsheet for the current command
bind -x '"\C-gb3": give_command_hint'

```

So now, we have make almost all the keybindings (there's one left `ctl-q` ).
Remember you must make a pretty generic keybinding in asyncBash.inputrc and then the actual user keybinding in my_fun.sh.


##Make the bash function

The last step is to make the function. Let's search for Functions and add: :)


```bash
###############
#  Functions  #
###############

#Display a cheatsheet for the current command
#from ~/.local/hints
give_command_hint() {
    asyncBash_add_msg_below_ps1 "I will show you a nice cheatsheet"
}
```

Hooray it works:

```bash
$>tell me (pressed Alt-h)

I will show you a nice cheatsheet
```

So let's fill it:

```bash
#Display a cheatsheet for the current command
#from ~/.local/hints
give_command_hint() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    #Clean possible previous asyncBash calls
    asyncBash_clean_screen_msgs
    local -a cmda=($asyncBash_current_cmd_line)
    local cmd=${cmda[0]}
    asyncBash_add_msg_below_ps1 "I will show you a nice cheatsheet for $cmd"
}
```

```bash
$>tell me (pressed Alt-h)

I will show you a nice cheatsheet for tell
```

So basically we check that there is a current command, clean possible previous messages from this framework and get the first command on the current command line.
We need now just check for a file in certain path a just show it!. :D
Let's say that ~/.local/hints/$cmd.txt is our path:

```bash
#Display a cheatsheet for the current command
#from ~/.local/hints
give_command_hint() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    #Clean possible previous asyncBash calls
    asyncBash_clean_screen_msgs
    local -a cmda=($asyncBash_current_cmd_line)
    local cmd=${cmda[0]}
    local file="$HOME/.local/hints/$cmd.txt"
    asyncBash_add_msg_below_ps1 "I will show you a nice cheatsheet for $cmd"
    while IFS= read -r line; do 
        asyncBash_add_msg_below_ps1 "$line"
    done < $file
    local write="${cmda[@]:-1}"
    #Substitute history line
    asyncBash_substitute_command_line "$write"
}
```

Let's try it:

```bash
$>journalctl (pressed Alt-h)

I will show you a nice cheatsheet for journalctl
DATES
-b: shows current boot
--list-boots: list boots
-b -N: previous N boot
--since yesterday/09:00/"2015-01-10"
--until yesterday/09:00/"2015-01-10"/"2015-01-10 17:15:00"
PROCESS
-u nginx.service
_PID=444  / _UID=345 /  SYSLOG_IDENTIFIER=firejail / ...
```

Wow. :D

Basically we have read the file line by line (proper way in bash), added each line to a queue to be displayed below the PS1 and finally rewrite the command line without the first '#', so 100% equal.

There is an obvious error we don't check for the file but the important is that there is a keybinding remaining already (did you remember `Ctl-q` to clean the screen?).


```bash
#Display a cheatsheet for the current command
#from ~/.local/hints
give_command_hint() {
    [[ -z $asyncBash_current_cmd_line ]] && return
    #Clean possible previous asyncBash calls
    asyncBash_clean_screen_msgs
    local -a cmda=($asyncBash_current_cmd_line)
    local cmd=${cmda[0]}
    local file="$HOME/.local/hints/$cmd.txt"
    if [[ -e $file  ]]; then
        bind -x '"\C-q": asyncBash_clean_screen_msgs'
        #show a legend with the possible arguments
        asyncBash_add_msg_below_ps1 "Enter Control-q to clean screen messages" yes
        while IFS= read -r line; do 
            asyncBash_add_msg_below_ps1 "$line"
        done < $file
    fi
    local write="${cmda[@]:-1}"
    #Substitute history line
    asyncBash_substitute_command_line "$write"
}

```

Ummm:


```bash
$>journalctl -rb (pressed Alt-h)
Enter Control-q to clean screen messages
DATES
-b: shows current boot
--list-boots: list boots
-b -N: previous N boot
--since yesterday/09:00/"2015-01-10"
--until yesterday/09:00/"2015-01-10"/"2015-01-10 17:15:00"
PROCESS
-u nginx.service
_PID=444  / _UID=345 /  SYSLOG_IDENTIFIER=firejail / ...

```

And then: 

```bash
$>journalctl -rb (pressed Ctr-q)

```

Here we are!.


It's so easy, nice and simple that I've made it along this tutorial and added to the default user functions. :rocket:

#FAQ

Why wasn't it invented before?

Now it is! :roller_coaster:

