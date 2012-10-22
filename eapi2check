FILES=$(find /usr/portage/ -type f -name *.ebuild)

for file in $FILES; do
  grep "EAPI=2" -q $file && grep KEY $file | grep -q -e "[\"|\ ]amd64"
  if [ $? -eq 0 ]; then
    STABLE+=" $(echo ${file##*portage/} | cut -d/ -f 1,3 | sed s/.ebuild//)"
  fi
  grep "EAPI=2" -q $file && grep KEY $file | grep -q -e "~amd64"
  if [ $? -eq 0 ]; then
    UNSTABLE+=" $(echo ${file##*portage/} | cut -d/ -f 1,3 | sed s/.ebuild//)"
  fi
done

echo -e "Stable packages with EAPI 2:"
echo -e ${STABLE//\ /\\n}
echo -e "\nUnstable packages with EAPI 2:"
echo -e ${UNSTABLE//\ /\\n}
