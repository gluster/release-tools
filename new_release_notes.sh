#!/bin/bash
#
# Generate release notes in Markdown format so that they can easily be included
# in the <glusterfs-repo>/docs/release-notes/ directory.
#
# This script expects the following parameters:
#
# 1: base version (git commit, tag, ..)
# 2: target version these release notes are for (the git commit, tag ..)
# 3: path to the git repository
#
# While this script runs, the output is printed to stdout. Afterwards the
# results can also be found in /tmp/release_notes.
#


function generate_release_notes ()
{
    local orig_version=$1
    local latest_version=$2
    local repo=$3
    local github_issue_list=$4

    cd "${repo}" || exit

    # step 1: gather all BUG numbers from the commit messages
    #         use format=email so that BUG: is at the start of the line
    # step 2: split the BUG: lines at the : position, only return the 2nd part
    # step 3: filter non-numeric lines, and strip off any spaces with awk
    # step 4: sort numeric, and only get occurences once (-u for unique)
    # step 5: use xargs to pass some of the bugs to the bugzilla command
    # step 6: show progress on the current terminal, and write to a file
    oldformat=$(git log --format=email "${orig_version}..${latest_version}" | grep -w -i ^BUG \
        | cut -d: -f2 \
        | awk '/^[[:space:]]*[0-9]+[[:space:]]*$/{print $1}' \
        | sort -n -u)

    newformat=$(git log --format=email "${orig_version}..${latest_version}" \
        | grep -w -E "([fF][iI][xX][eE][sS]|[uU][pP][dD][aA][tT][eE][sS])(:)?[[:space:]]+(gluster\\/glusterfs)?(bz)#[[:digit:]]+" \
	| grep -v "^>" \
        | awk -F '#' '{print $2}' \
        | sort -n -u)

    bugs=$(echo "${oldformat}" "${newformat}" | tr " " "\\n" | sort -n -u)

    echo "$bugs" \
        | xargs -r -n1 bugzilla query --outputformat='- [#%{id}](https://bugzilla.redhat.com/%{id}): %{summary}' -b \
        | tee /tmp/release_notes

    githubissues=$(git log --format=email "${orig_version}..${latest_version}" \
        | grep -w -E "([fF][iI][xX][eE][sS]|[uU][pP][dD][aA][tT][eE][sS])(:)?[[:space:]]+(gluster\\/glusterfs)?#[[:digit:]]+" \
	| grep -v "^>" \
        | awk -F '#' '{print $2}' \
        | sort -n -u)

#    echo "githubissues are :"
#    echo "${githubissues}"
    issues=$(echo  "${githubissues}" | tr " " "\\n" | sort -n -u)
   
    echo "$issues" > /tmp/issue

# Note I am assuming that typescript is given as input and is in /tmp/directory 
    grep -o "^....................................................................................." $github_issue_list  > /tmp/issues-without-label.txt
    echo "" > /tmp/result.txt
    while read line
    do
          grep $line /tmp/issues-without-label.txt >> /tmp/result.txt
    done < /tmp/issue

    sed -ri '/^\s*$/d' /tmp/result.txt
    awk '{ $1=$1"](https://github.com/gluster/glusterfs/issues/"$1")" ; print $0 }' /tmp/result.txt  > /tmp/result2.txt
    sed -i 's/#//g' /tmp/result2.txt
    sed -i 's/^/[#/g' /tmp/result2.txt
    cat /tmp/result2.txt
    

}

function main ()
{
    generate_release_notes "$1" "$2" "$3" "$4";
}

if [ $# -ne 4  ]
then 
  echo; echo "Usage: $0 <starting commit id or tag> <ending commit id or tag > <path to the repository> <file containing the list of github issues>"
  echo; echo "eg:"
  echo; echo "    # $0  v8dev v8.0alpha   /Code/glusterfs /tmp/typescript"
  echo;echo
  echo;echo "Here is how you can generate a file containing the list of github issues :"
  echo      "fire following commands in the gluster code repository cloned via gh cli :"
  echo;echo "     $ script"
  echo      "     $ gh issue list -L 600 "
  echo      "     $ logout"
  echo;echo "In the current directory you should see the typescript" 
  echo      "move this file to /tmp"
  echo;echo "     $ mv typescript /tmp"
  echo;
  exit
fi

main "$@"
