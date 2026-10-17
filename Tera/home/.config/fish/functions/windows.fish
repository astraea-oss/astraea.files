function windows
    sudo -n /usr/bin/efibootmgr -n 0000; and sudo -n /usr/bin/systemctl reboot
end
