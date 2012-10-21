#!/bin/bash

# generates two filenames for the temporary files
TMPFILE_1=$(/bin/mktemp -t vim.$$.XXXXXXXX) || ( echo "Can't use file name. Exiting." && exit 1 )
TMPFILE_2=$(/bin/mktemp -t vim.$$.XXXXXXXX) || ( echo "Can't use file name. Exiting." && exit 1 )

# checks if two directories were given
# if not, present usage description
[[ ! -d $1 || ! -d $2 ]] && {
  echo -e "Compares the contents of two directories recursively according to:\n"
  echo -e "\t- acces privileges\n\t- owner\n\t- group\n"
  echo -e "Usage:\n\t$0 <directory_1> <directory_2>\n"
  WILL_RUN=0
}

# if $WILL_RUN is not set to zero, compare the directory hierarchies
if [[ $WILL_RUN != 0 ]]; then

  ls -lR $1 | awk '{print $1"\t"$3"\t"$4"\t"$9}' > $TMPFILE_1;
  ls -lR $2 | awk '{print $1"\t"$3"\t"$4"\t"$9}' > $TMPFILE_2;

  # start vimdiff on the two temp files without spell checking
  /usr/bin/vimdiff -c "set nospell" $TMPFILE_1 $TMPFILE_2

fi

# delete the temporary files files after use afterwards
rm $TMPFILE_1 $TMPFILE_2
