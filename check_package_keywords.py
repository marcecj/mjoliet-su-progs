#!/usr/bin/env python3

import os
import re
import portage

def unique(l):
    l_e = l
    for e in l:
        while l_e.count(e) > 1:
            l_e.remove(e)
    return l_e

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

# pk_reg = re.compile(pkg_str + "(?:-)?" + ver_str)
pk_reg = re.compile(pkg_str)

# reg.findall() also returns empty matches, so filter those with a len() check
packages = [m for l in lines for m in pk_reg.findall(l) if len(m)>0]
packages = unique(packages)

max_p_len = max([len(p) for p in packages])
form_spec = "{0:>" + str(max_p_len) + "}: {1:>12} -> {2:<12}"

# get a list of all installed packages
var_tree = portage.vartree()
installed_pkgs = var_tree.getallcpv()

for p in packages:
    available = portage.portdb.cp_list(p)
    installed = [b for b in available if b in installed_pkgs]
    av_ver    = unique(['-'.join(portage.pkgsplit(m)[1:]) for m in available])
    ins_ver   = unique(['-'.join(portage.pkgsplit(m)[1:]) for m in installed])

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
