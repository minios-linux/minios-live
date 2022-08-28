#
# parse the output of "dracut --profile" and produce profiling information
#
# Copyright 2011 Harald Hoyer <harald@redhat.com>
# Copyright 2011 Red Hat, Inc.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import sys
import operator
import re
loglines = sys.stdin

logpats  = r'[+]+[ \t]+([^ \t]+)[ \t]+([^ \t:]+):[ ]+.*'

logpat   = re.compile(logpats)

groups   = (logpat.match(line) for line in loglines)
tuples   = (g.groups() for g in groups if g)

def gen_times(t):
    oldx=None
    for x in t:
        fx=float(x[0])
        if oldx:
            #print fx - float(oldx[0]), x[0], x[1], oldx[0], oldx[1]
            if ((fx - float(oldx[0])) > 0):
                    yield (fx - float(oldx[0]), oldx[1])

        oldx = x

colnames = ('time','line')

log      = (dict(zip(colnames,t)) for t in gen_times(tuples))

if __name__ == '__main__':
    e={}
    for x in log:
        if not x['line'] in e:
            e[x['line']] = x['time']
        else:
            e[x['line']] += x['time']

    sorted_x = sorted(e.iteritems(), key=operator.itemgetter(1), reverse=True)
    for x in sorted_x:
        print x[0], x[1]

