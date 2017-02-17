#!/bin/sh

BASE_URL="http://distfiles.gentoo.org/releases/amd64/autobuilds/"
LATEST="${BASE_URL}latest-stage3-amd64-systemd.txt"
STAGE3_URL="${BASE_URL}$(curl -s $LATEST | tail -n1 | cut -d' ' -f1)"

container_name="gentoo-amd64-systemd"
while getopts n: a
do
    case $a in
	n) container_name="$OPTARG";;
	\?) exit 1;;
    esac
done

# create the initial container from the current stage3 image
machinectl pull-tar --verify=no "${STAGE3_URL}" "${container_name}"

# make sure the machine mounts the systems distfiles as a read-only FS
cat <<EOF > "/etc/systemd/nspawn/${container_name}.nspawn"
[Files]
BindReadOnly=/home/marcec/projects/gentoo/:/home/marcec/gentoo/
BindReadOnly=/usr/portage/distfiles/:/usr/portage/ro_distfiles/
EOF

### configure portage

host_cpu_flags="$(grep CPU_FLAGS /etc/portage/make.conf)"
systemd-nspawn -M "${container_name}" sh -c "
mkdir \
	  /etc/portage/env \
	  /etc/portage/package.accept_keywords \
	  /etc/portage/package.env \
	  /etc/portage/package.use \
	  /etc/portage/profile

echo 'app-text/asciidoc -python_targets_pypy -python_single_target_pypy' > /etc/portage/profile/package.use.mask
echo 'FEATURES=\"\${FEATURES} test\"' > /etc/portage/env/test.conf
echo 'app-text/asciidoc test.conf' > /etc/portage/package.env/test

cat << EOF > /etc/portage/package.accept_keywords/asciidoc
app-text/asciidoc **
~dev-python/pypy-bin-5.6.0 ~amd64
~virtual/pypy-5.6.0 ~amd64
EOF

cat << EOF > /etc/portage/package.use/asciidoc
# app-text/asciidoc python_targets_pypy python_single_target_pypy -python_single_target_python2_7
app-text/asciidoc python_targets_pypy

# required by media-sound/lilypond-2.18.2::gentoo
# required by app-text/asciidoc-8.6.9-r1::gentoo[test]
# required by asciidoc (argument)
>=media-gfx/fontforge-20150612-r1 png
# required by media-gfx/graphviz-2.38.0-r1::gentoo
# required by app-text/asciidoc-8.6.9-r1::gentoo[test]
# required by asciidoc (argument)
>=media-libs/gd-2.1.1 truetype png fontconfig jpeg

# fetching from github requires curl support in git
dev-vcs/git curl

# required by app-text/texlive-core-2014-r4::gentoo[xetex]
# required by dev-texlive/texlive-mathextra-2014::gentoo
# required by app-text/dblatex-0.3.7::gentoo
# required by dblatex (argument)
>=media-libs/harfbuzz-0.9.41 icu
# required by dev-texlive/texlive-xetex-2014::gentoo
# required by app-text/dblatex-0.3.7::gentoo
# required by dblatex (argument)
>=app-text/texlive-core-2014-r4 xetex
EOF

sed -i s:USE=.\*:USE=\\\"-X\\\":g /etc/portage/make.conf
echo '${host_cpu_flags}' >> /etc/portage/make.conf

cat << EOF >> /etc/portage/make.conf
PORTAGE_RO_DISTDIRS=\"\\\${PORTDIR}/ro_distfiles\"
EMERGE_DEFAULT_OPTS=\"--with-bdeps=y --quiet-build=y --nospinner --jobs 2 --load-average 4 --keep-going\"
EOF
"

### update the system and install desired packages

systemd-nspawn -M "${container_name}" emerge-webrsync
systemd-nspawn -M "${container_name}" emerge --sync
systemd-nspawn -M "${container_name}" eix-update
systemd-nspawn -M "${container_name}" emerge @world -uDNv
systemd-nspawn -M "${container_name}" emerge -v \
        app-editors/vim \
        app-portage/eix \
        app-portage/gentoolkit \
        app-text/asciidoc \
        app-text/dblatex \
        dev-vcs/git \
        virtual/pypy
