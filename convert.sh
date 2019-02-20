#!/bin/bash

SVN_HOST=''
GIT_REMOTE_PATH=''
SVNUSER=''

if [ -f ".config" ]; then
  source ".config"
fi

if [ -z ${1+x} ]; then
  echo 'The SVN repository is required'
  echo ''
  echo '  usage:  ./convert.sh <svn-repo-name> [<branch-path>]'
  echo ''
  echo '     <svn-repo-name>:  the name of the SVN repository to convert'
  echo '       <branch-path>:  (optional) name of the branches path (typically "branches" or "branch")'
  echo ''
  exit -1
fi

REPONAME=$1
BRANCHES=${2:-"branches"}
GITREPO="$REPONAME"

echo "SVN Repository: $REPONAME"
echo "Branches path: $BRANCHES"
echo ''
read -p "Is this correct (y/n)? " yesno
if [ "y" != "$yesno" ]; then
  exit 1
fi

echo ''
read -p "Enter SVN Host [$SVN_HOST]: " SVN_HOST_IN
if [ ! -z "${SVN_HOST_IN}" ]; then
  SVN_HOST=$SVN_HOST_IN
  echo "Updating SVN_HOST to $SVN_HOST"
fi

read -p "Enter SVN username [$SVNUSER]: " SVNUSER_IN
if [ ! -z "${SVNUSER_IN}" ]; then
  SVNUSER=$SVNUSER_IN
  echo "Set SVN username to $SVNUSER"
fi

read -p "Enter Git remote [$GIT_REMOTE_PATH]: " GIT_REMOTE_PATH_IN
if [ ! -z "${GIT_REMOTE_PATH_IN}" ]; then
  GIT_REMOTE_PATH=$GIT_REMOTE_PATH_IN
  echo "Updating SVN_HOST to $GIT_REMOTE_PATH"
fi

read -p "Git repo name [$GITREPO]: " GITREPO_IN
if [ ! -z "${GITREPO_IN}" ]; then
  GITREPO=$GITREPO_IN
  echo "Setting Git repo name to $GITREPO"
fi

echo "SVN_HOST=\"$SVN_HOST\"" > ".config"
echo "GIT_REMOTE_PATH=\"$GIT_REMOTE_PATH\"" >> ".config"
echo "SVNUSER=\"$SVNUSER\"" >> ".config"

WORKPATH=`pwd`
echo "Work path: $WORKPATH"


echo "Ready to convert: $REPONAME"
read -p "Press any key to continue... " -n1 -s

git svn clone $SVN_HOST/$REPONAME/ --username "$SVNUSER" --no-metadata -A authors-transform.txt --stdlayout ./temp --branches=$BRANCHES

cd "$WORKPATH/temp"
git checkout origin/trunk
git svn show-ignore --id=origin/trunk > .gitignore
#git add .gitignore
#git commit -m 'Converted snv:ignore to .gitignore'

echo 'Cloned the SVN repo to temp and extracted the gitignore'
read -p "Press any key to continue... " -n1 -s

# make a new git bare repo
cd "$WORKPATH"
git init --bare "./$REPONAME.git"
cd "$WORKPATH/$REPONAME.git"
git symbolic-ref HEAD refs/heads/trunk

echo 'Created a new bare git repo; ready to push to it'
read -p "Press any key to continue... " -n1 -s

# push from the git-svn proxy repo to the true bare git repo
cd "$WORKPATH/temp"
git remote add bare "$WORKPATH/$REPONAME.git"
git config remote.bare.push 'refs/remotes/*:refs/heads/*'
git push bare

# fix up the trunk -> master branch
cd "$WORKPATH/$REPONAME.git"
git branch -m origin/trunk master
git symbolic-ref HEAD refs/heads/master

# convert all tags, and branchs
git for-each-ref --format='%(refname)' refs/heads/origin/tags | cut -d / -f 5 | while read ref; do   git tag "$ref" "refs/heads/origin/tags/$ref";   git branch -D "origin/tags/$ref"; done
git for-each-ref --format='%(refname)' refs/heads/origin | cut -d / -f 4 | while read ref; do git branch -m "origin/$ref" "$ref"; done

# add a remote repo
git remote add tgt "$GIT_REMOTE_PATH$GITREPO.git"
# push all branchs from the bare to the remote beanstalk repo
git for-each-ref --format='%(refname)' refs/heads | cut -d / -f 3 | while read ref; do git push tgt $ref; done

read -p "Conversion complete. Ready to add .gitignore. Press any key to continue... " -n1 -s

mv "$WORKPATH/temp/.gitignore" "$WORKPATH/$REPONAME.git/"
cd "$WORKPATH/$REPONAME.git"
git checkout master
git add .gitignore
git commit -m "Added .gitignore"
git push