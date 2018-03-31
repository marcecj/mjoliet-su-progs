#!/bin/sh
grub2-mkimage -O i386-efi -o grub.efi configfile btrfs fat part_gpt normal linux ls boot echo reboot search search_fs_file search_fs_uuid search_label help font efi_gop efi_uga gfxterm gzio
