#!/usr/bin/env python3

import os
import re
import subprocess as subp

def unique(l):
    l_e = l
    for e in l:
        while l_e.count(e) > 1:
            l_e.remove(e)
    return l_e

def version_is_larger(v1, v2):
    """ Function to compare two version numbers and report whether v1 is larger than v2 or not.
    """

    is_larger = None

    # regex that generates a tuple with the base version and the revsion/RC/etc.
    # ver_reg   = re.compile("([0-9.]*)[_-]?([rcpe]*)([0-9rcpe]*)")

    # regex that generates a 4-tuple consisting of:
    #   - the base version
    #   - the type of version "appendix" (rc/p/etc.)
    #   - the actual version appendix
    #   - the ebuild revision
    # TODO: this won't work for versions of the form <version><letter> (i.e.
    # like Matlab, e.g. "2010a"). Doesn't Portage or some additional package
    # contain a function that does this correctly?  I must check up on that.
    ver_reg = re.compile("([0-9.]*)[_]?(?:(rc|pre|p)+([0-9]*))?(?:-r([0-9]*))?")

    # various version appendages
    append_sort = {
        'rc': 0,  # release candidate
        'pre':1,  # pre-release
        'p':  2,  # patch level
    }

    a_ver   = ver_reg.findall(v1)[0]
    i_ver   = ver_reg.findall(v2)[0]
    a_ver_d = [m for m in a_ver[0].split('.') if len(m) > 0]
    i_ver_d = [m for m in i_ver[0].split('.') if len(m) > 0]

    # for each sub-version number check which is larger
    for n in zip(a_ver_d, i_ver_d):
        try:
            gt = int(n[0]) > int(n[1])
            lt = int(n[0]) < int(n[1])
        except ValueError:
            gt = n[0] > n[1]
            lt = n[0] < n[1]

        # as soon as a sub-version is larger or smaller than the currently
        # installed version, we know we can skip it
        if gt:
            is_larger = True
            break
        elif lt:
            is_larger = False
            break

    if is_larger is None and len(a_ver_d) == len(i_ver_d):
        if len(a_ver[1]) > 0:
            if append_sort[a_ver[1]] == append_sort[i_ver[1]]:
                is_larger = int(a_ver[2]) > int(i_ver[2])
            else:
                is_larger = append_sort[a_ver[1]] > append_sort[i_ver[1]]
        elif len(a_ver[3])>0 and len(i_ver[3])>0:
            is_larger = int(a_ver[3]) > int(i_ver[3])
        else:
            is_larger = a_ver[3] > i_ver[3]
            
    elif is_larger is None:
        is_larger = len(a_ver_d) > len(i_ver_d)

    # print(is_larger, a_ver, i_ver)
    return is_larger

fname = "/etc/portage/package.accept_keywords"
if os.path.isfile(fname):
    with open(fname) as pk:
        lines = pk.readlines()
elif os.path.isdir(fname):
    lines = []
    for root, dirs, files in os.walk(fname):
        files = [os.path.join(root, f) for f in files if not f.endswith('~')]
        for f in files:
            with open(f) as fp:
                lines += fp.readlines()

# match an uncommented package entry:
#   - start of the line (0 or more spaces, without a comment)
#   - the version "range" prefix
#   - "<base>-<cat>/<name>"
#   - "-<anything>" (presumably the package version)
pkg_str = \
"^\s*#{0}\s*\
[><=~]?\
(\w+(?:-\w+)?/\w+(?:-[a-zA-Z]+\w*)*){1}"

# a package version regex:
#   - ignore slots and overlays, which are surrounded in round and square
#     brackets, respectively
#   - a "base" vesion plus zero or more letters
#   - a version "appendix" (e.g., pre*, p*, rc*)
#   - the ebuild revision
ver_str = \
"(?<!\(|\[)([0-9.]+[a-z]*\
(?:[_-]?[a-z]*[0-9]+[a-z]*)?\
(?:-r[0-9]+)?)(?!\)|\])"

# pk_reg = re.compile(pkg_str + "(?:-)?" + ver_str)
pk_reg = re.compile(pkg_str)
ver_reg = re.compile(ver_str)

# reg.findall() also returns empty matches, so filter those with a len() check
packages = [m for l in lines for m in pk_reg.findall(l) if len(m)>0]
packages = unique(packages)

shell = subp.Popen('sh', stdout=subp.PIPE, stdin=subp.PIPE,
                   universal_newlines=True)

eix_cmd = "/usr/bin/eix --pure-packages --exact" 
eix_opt = ("--format '<installedversions:VSORT>\n'",
            "--format '<availableversions:VSORT>\n'")

max_p_len = max([len(p) for p in packages])
form_spec = "{0:>" + str(max_p_len) + "}: {1:>12} -> {2:<12}"

for p in packages:
    installed = subp.getoutput(' '.join([eix_cmd, p, eix_opt[0]]))
    # print(installed)
    available = subp.getoutput(' '.join([eix_cmd, p, eix_opt[1]]))
    ins_ver   = unique([m for m in ver_reg.findall(installed) if len(m)>0])
    av_ver    = unique([m for m in ver_reg.findall(available) if len(m)>0])


    if ins_ver:
        # cur_ver = [v for v in av_ver if version_is_larger(v, ins_ver[0])]
        try:
            idx     = av_ver.index(ins_ver[0])
        except ValueError:
            idx = -1
            ins_ver = ["*" + v for v in ins_ver]
            
        # TODO: handle slots properly
        # cur_ver = (av_ver[idx+1:] if idx+1<len(av_ver) and ins_ver[0] not in av_ver[idx+1:] else [])
        cur_ver = [v for v in av_ver[idx+1:] if ins_ver[0] != v]
        # print(av_ver[idx+1:])
        # print(p, ins_ver, cur_ver)
        
        # skip the package if the only upgrade is a live ebuild
        if len(cur_ver) == 1 and cur_ver[0].startswith('9999'):
            continue

        # the additional "and" is necessary in case the version is available
        # from multiple sources
        # if len(cur_ver)>0 and ins_ver[0] not in cur_ver:
        if len(cur_ver)>0:
            print(form_spec.format(p, ', '.join(ins_ver), ', '.join(cur_ver)))
    else:
        if len(av_ver)>0:
            print(form_spec.format(p, '(none)', ', '.join(av_ver)))

shell.communicate('exit'.encode())
