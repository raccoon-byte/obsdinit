#!/bin/sh

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

ask_yes_no() {
  while true; do
    printf "%s [%s]: " "$1" "$2" > /dev/tty
    read -r response
    case "$response" in
      [Yy]*|"") return 0 ;;
      [Nn]*) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

get_username() {
    # Enter username
    echo "Enter your desired username (lower-case loginname)" > /dev/tty
    while read -r username; do
        if [ "$username" = "$prev_username" ]; then
            break
        fi
        prev_username=$username
        echo "Enter your username again (username must match)" > /dev/tty
    done
    echo "$username"
}

get_full_name() {
    # Enter full name
    echo "Enter your full name (it can be changed later)" > /dev/tty
    read -r full_name
    echo "$full_name"
}

add_user() {
    local username="$1"
    local full_name="$2"

    # Enter password
    echo "Password for the new account? (will not echo)" > /dev/tty
    stty -echo
    while read -r pass; do
        if [ "$pass" = "$prev_pass" ]; then
            break
        fi
        prev_pass=$pass
        echo "Password for the new account? (again)" > /dev/tty
    done
    stty echo

    #Create the new user
    adduser -noconfig -class "staff" -shell "ksh" -batch "$1" operator,staff,wheel "$2" "$(encrypt "$pass")"
}

enable_apmd() {
    rcctl enable apmd
    rcctl set apmd flags -L
    rcctl start apmd
}

install_packages() {
    # Install software
    echo "Installing software..." > /dev/tty
    pkg_add wget-- curl-- freetype-- weechat-- unzip-- neovim-- gmake-- git-- 
    curl -fLo /usr/local/bin/yadm https://github.com/TheLocehiliosan/yadm/raw/master/yadm && chmod a+x /usr/local/bin/yadm
}

install_graphical_interface () {
    # Install related graphical packages
    pkg_add picom-- xwallpaper-- nsxiv-- hermit-font-- symbola-ttf-- mpv-- xdotool-- xclip-- surf-- maim-- sxhkd-- dwm-- st-- dmenu--
}

# ---

username=$(get_username)
full_name=$(get_full_name)
# Add user
add_user "$username" "$full_name" || error "Unable to add a new user"
# Allow user to use the doas command
echo "permit persist :wheel" > /etc/doas.conf
# Enable APMD
ask_yes_no "Do you want to enable APMD?" "yes"
if [ $? -eq 0 ]; then
    enable_apmd || error "Unable to enable APMD"
fi
# Install packages
install_packages || error "Unable to install packages"
# Install graphical interface
ask_yes_no "Do you want to install the graphical interface?" "yes"
if [ $? -eq 0 ]; then
    # Enable xenodm
    rcctl -f enable xenodm
    ask_yes_no "Do you want to enable autologin for the graphical interface? (Recommended if you encrypted your disk)" "yes"
    if [ $? -eq 0 ]; then
        # Disable password prompt in xenodm
        echo "DisplayManager.*.autoLogin:	$username" >>/etc/X11/xenodm/xenodm-config
    fi
    install_graphical_interface || error "Unable to install the graphical interface"
fi
echo "All done!"

