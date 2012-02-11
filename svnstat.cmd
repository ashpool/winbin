@setlocal enableextensions & python -x %~f0 %* & goto :EOF

# svnstat is a port of gitstat https://github.com/wouterdebie/systemfiles/blob/master/dotfiles/bin/gitstat
#
# the svnstat program parses the output of svn log and reports on the
# changes it finds. It gives a summary of commits done by specific people
#
# usage svnstat [options] 
#
import sys
import os
from optparse import OptionParser

VERSION="svnstat 0.1"

# current commit we're reading from svn log
cur = []

# records total commits per author along with lines changed
authors = {}

# records the summary line for each sob, acked-by etc for each person of
# interest
involved = {}
involved_hit = {}
email_hash = {}

# we want to send output through less, but only when we have more than
# a full screen of output.
#
class pager:
    def __init__(self):
        self.buffering = True
        self.paging = False
        self.pipefd = sys.stdout
        self.buf = []
        self.rows = self.window_rows()

    def window_rows(self):
        try:
            import termios, fcntl, struct
            s = struct.pack("HHHH", 0, 0, 0, 0)
            fd_stdout = sys.stdout.fileno()
            x = fcntl.ioctl(fd_stdout, termios.TIOCGWINSZ, s)
            (rows, cols, x, y) = struct.unpack("HHHH", x)
        except:
            rows = 24
        return rows

    def __del__(self):
        self.close()

    def close(self):
        if self.buffering:
            if self.buf and sys.stdout:
                sys.stdout.write("".join(self.buf))
                self.buf = []
        if self.paging:
            self.pipefd.close()

    def write(self, line):  
        self.pipefd.write(line)

# simple helper to pull out a name from an email address
# it just looks for full name <full email> and drops the full email
#
def name_from_email(line):
    line = line.lstrip()
    index = line.find('<')
    if index <= 1:
        return line
    name = line[:index - 1]
    comma = name.find(',')
    if comma < 0:
        return name
    last = name[:comma]
    rest = name[comma + 1:]
    return "%s %s" % (rest.lstrip().rstrip(), last.rstrip())

def email_only(line):
    line = line.lstrip().rstrip().lower()
    start = line.find('<')
    end = line.find('>')
    if start < 0 or end < 0:
        return line
    return line[start + 1:end]

def short_name(line):
    line = line.lstrip().rstrip().lower()
    name = name_from_email(line)
    words = name.split()
    first = words[0]
    last = words[-1]
    return "%s %s" % (first, last)

# check a given line with a tag (author, sob, etc) against the list
# of emails we are searching for.  Returns true if it is a commit
# we want to report.
def should_include_person(line):
    line = line.lower()
    if not options.email and not email_hash:
        return True

    for x in options.email:
        if x in line:
            return True

    name = name_from_email(line.rstrip().lstrip()).lower()

    if name in email_hash:
        return True

    name = email_only(line)
    if name in email_hash:
        return True

    name = short_name(line)
    if name in email_hash:
        return True

    return False

def is_log_entry(lines):
   return len(lines) >= 2

# this does all the work of deciding if we want to include a given
# commit, and adding it into the hash tables if it matches our
# criteria.  It also feeds the commit to diffstat if
# appropriate.
#
def add_commit(lines, added, removed, diffpipe):
    if not is_log_entry(lines):
        return

    words = lines[1].split()
    revision = words[0].rstrip()
    orig_author = words[2].rstrip()
    timestamp = " ".join(words[4:7]).lstrip("|")
    commit_message = ""	

    if len(lines) >= 3:
        commit_message = "".ljust(46, " ").join(lines[3:]) 

    commit = "%s %s %s" % (revision.ljust(7, " "), timestamp.ljust(28, " "), commit_message)
    
    author = orig_author.lower()

    if should_include_person(author):
        # create a full commit record
        if diffpipe:
            for d in lines:
                diffpipe.write(d)

        short = name_from_email(orig_author)
        if not options.full_name:
            author = short

        # total commit, total lines added, removed, commit rec, name
        ar = authors.setdefault(author, [0, 0, 0, [], short])
        commit = [[commit.rstrip().lstrip()], added, removed]
        
        ar[0] += 1
        ar[1] += added
        ar[2] += removed
        ar[3].append(commit)
       

# fire up diffstat, writing output to a temp file.  Return the
# tmp file and the diffstat pipe.
#
def start_diffstat():
    import tempfile

    fp = tempfile.NamedTemporaryFile()
    pipe = os.popen("diffstat -p1 > %s" % fp.name, 'w')
    if not pipe:
        os.stderr.write("failed to create diff pipe\n")
    return (fp, pipe)


# close the diffstat pipe and print the output
#
def print_diffstat(fp, pipe):
    if not fp:
        return

    pipe.close()
    fp.seek(0)
    lines = []
    last = None
    while True:
        x = fp.readline()
        if not x:
            break
        if last:
            words = last.split()
            if '+' in words[-1] or '-' in words[-1]:
                val = int(words[-2])
            else:
                val = int(words[-1])

            lines.append((val, last))
        last = x
    lines.sort(reverse=True)
    for x in lines:
        print >> output, x[1],
    #print last
    fp.close()


def setup_email_hash():
    global email_hash

    for x in options.email:
        email_hash[x] = 1

    if not options.email_file:
        return

    fp = file(options.email_file)
    while True:
        line = fp.readline()
        if not line:
            break;
        line = line.rstrip().lstrip()
        if not line:
            continue

        name = name_from_email(line).lower()
        email_hash[name] = 1

        name = email_only(line)
        email_hash[name] = 1

        name = short_name(line)
        email_hash[name] = 1


def run_svn_log(flags, args):
    fp = os.popen("svn log %s %s" % (flags, " ".join(args)))
    return fp


# does all the sorting and other setup to actually print the commits
def print_commits(commits):
    global total_added
    global total_removed

    # don't print a line count when there is only one commit
    should_lc = not options.no_commit_line_counts and len(commits) > 1

    # sort based on revision
    sort = {}
    for commit in commits:
	
        line = commit[0][0].lstrip()

        idx = line.find(' ')
        if (idx > 0):
            line = int(line[:idx].lstrip("r"))
        sort.setdefault(line, []).append(commit)
    keys = sort.keys()
    keys.sort()
    commits = []
    for x in keys:
        ar = sort[x]
        for c in ar:
            commits.append(c)

    count = 0
    for commit in commits:
        total_added += commit[1]
        total_removed += commit[2]
        summary = commit[0][0]

        str1 = "    %s" % summary

        if not should_lc:
            print >> output, "%s" % str1
            continue

        print >> output, "%s" % (str1)

        # there are extra lines in the commit when we
        # were run with -c
        #
        for x in commit[0][1:]:
            print >> output, "        %s" % x
        if len(commit[0]) > 1:
            print >> output, ""

        count += 1
        if options.limit and count > options.limit:
            break

usage = "usage: %prog [options]"
parser = OptionParser(usage=usage)

revision_help = """-r [--revision] arg      : ARG (some commands also take ARG1:ARG2 range)
                           A revision argument can be one of:
                              NUMBER       revision number
                              "{" DATE "}" revision at start of the date
                              "HEAD"       latest in repository
                              "BASE"       base rev of item's working copy
                              "COMMITTED"  last commit at or before BASE
                              "PREV"       revision just before COMMITTED"""

parser.add_option("-R", "--revision", 
                  help = revision_help, 
                  default="")
parser.add_option("-b", "--stop-on-copy", 
                  help="do not cross copies while traversing history", 
                  default=False, action="store_true")
parser.add_option("-V", "--verbose", 
				                  help="print extra information", 
				                  default=False, action="store_true")
parser.add_option("-r", "--report-header", 
                  help="Report header", 
                  default="")
parser.add_option("-f", "--full-name", help="Include full email in report",
                  default=False, action="store_true")
parser.add_option("-e", "--email", help="Email addresses of interest",
                  default=[], action="append")
parser.add_option("-E", "--email-file",
                  help="File with email addresses of interest",
                  default=None)
parser.add_option("-n", "--no-commit-line-counts",
                  help="Don't print a line count for each commit",
                  default=False, action="store_true")
parser.add_option("-v", "--version", help="Print version number",
                  default=False, action="store_true")
parser.add_option("-d", "--diffstat", help="Print diffstat",
                  default=False, action="store_true")
parser.add_option("-p", "--pipe",
                  help="Read from stdin instead of starting svn log",
                  default=False, action="store_true")
parser.add_option("-l", "--limit", help="Limit output per person",
                  default=0, type="int")
parser.add_option("-N", "--number-sort", help="Sort authors by number of commits",
                  default=False, action="store_true")
parser.add_option("-S", "--no-sort", help="Don't sort output",
                  default=False, action="store_true")

(options,args) = parser.parse_args()

if options.version:
    sys.stderr.write("%s\n" % VERSION)
    sys.exit(0)


# push all the email addresses to lower case for matching
ar = [ x.lower() for x in options.email ]
options.email = ar

added = 0
removed = 0
in_diff = False

# optionally start up diffstat
if options.diffstat:
    (difffp, diffpipe) = start_diffstat()
else:
    (difffp, diffpipe) = (None, None)

#setup_email_hash()


# figure out if we are running svn log or using stdin
if not options.pipe:
    #svn_args = "-M --no-merges -p"
    svn_args = ""
    if options.revision:
        svn_args += " --revision "
        svn_args += options.revision 
    if options.stop_on_copy:
        svn_args += " --stop-on-copy"
    if options.verbose:
        svn_args += "--verbose"

    input = run_svn_log(svn_args, args)
else:
    input = sys.stdin

#print options.all

# read in all the commits
while True:
    l = input.readline()
    if not l:
        break;
    if l.startswith('------'):
        if cur:
            add_commit(cur, added, removed, diffpipe)
            cur = []
            added = 0
            removed = 0
            in_diff = False
    if (l.startswith('+++ ') and cur[-1].startswith('--- ') and
        cur[-2].startswith('index ')):
        in_diff = True
    elif in_diff and not l.startswith('+++ ') and not l.startswith('--- '):
        if l.startswith('+'):
            added += 1
        elif l.startswith('-'):
            removed += 1
    cur.append(l)

if cur:
    add_commit(cur, added, removed, diffpipe)

output = pager()


if options.report_header:
    print >> output, options.report_header
    print >> output, ""

total_added = 0
total_removed = 0
total_commits = 0

if options.number_sort:
    sorted = {}
    for x in authors:
        ar = authors[x]
        sorted.setdefault(len(ar[3]), []).append(x)
    keys = sorted.keys()
    keys.sort()
    names = []
    for x in keys.__reversed__():
        for name in sorted[x]:
            names.append(name)
else:
    names = authors.keys()
    #names.sort()

for x in names:
    ar = authors[x]
    if options.full_name:
        name = x
    else:
        name = ar[4]

    print >> output, "%s (%d) commits:" % (name, ar[0])
    total_commits += len(ar[3])

    print_commits(ar[3])

    print >> output, ""


if not options.diffstat:
    print >> output, "Total: (%d) commits" % (total_commits)
else:
    print >> output, "Total: (%d) commits" % total_commits

print >> output, ""
print_diffstat(difffp, diffpipe)
output.close()