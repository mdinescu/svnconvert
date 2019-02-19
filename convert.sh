#!/bin/bash

SVN_HOST=#TODO: define the SVN host
GIT_REMOTE_PATH=#TODO: define the Git remote

if [ -z ${1+x} ]; then
  echo 'The SVN repository is required'
  echo ''
  echo 'usage:  ./convert.sh "svn-remo-name" "svn-user=name"'
  echo ''
  exit -1
fi
if [ -z ${2+x} ]; then
  echo 'The SVN username is required'
  echo ''
  echo 'usage:  ./convert.sh "svn-remo-name" "svn-user=name"'
  echo ''
  exit -1
fi

REPONAME=$1
SVNUSER=$2
BRANCHES=${3:-"branches"}
GITREPO="$REPONAME-git"

echo "Ready to convert: $REPONAME"
read -p "Press any key to continue... " -n1 -s

git svn clone $SVN_HOST/$REPONAME/ --username $SVNUSER --no-metadata -A authors-transform.txt --stdlayout ./temp --branches=$BRANCHES

#cd temp
#git checkout origin/trunk
#git svn show-ignore --id=origin/trunk > .gitignore
#git add .gitignore
#git commit -m 'Converted snv:ignore to .gitignore'

echo 'Cloned the SVN repo to temp and updated the gitignore'
read -p "Press any key to continue... " -n1 -s

# make a new git bare repo
git init --bare ./$REPONAME.git
cd $REPONAME.git
git symbolic-ref HEAD refs/heads/trunk

echo 'Created a new bare git repo; ready to push to it'
read -p "Press any key to continue... " -n1 -s

# push from the git-svn proxy repo to the true bare git repo
cd ../temp
git remote add bare ~/dev/vast/$REPONAME.git
git config remote.bare.push 'refs/remotes/*:refs/heads/*'
git push bare

# fix up the trunk -> master branch
cd ../$REPONAME.git
git branch -m origin/trunk master
git symbolic-ref HEAD refs/heads/master

# convert all tags, and branchs
git for-each-ref --format='%(refname)' refs/heads/origin/tags | cut -d / -f 5 | while read ref; do   git tag "$ref" "refs/heads/origin/tags/$ref";   git branch -D "origin/tags/$ref"; done
git for-each-ref --format='%(refname)' refs/heads/origin | cut -d / -f 4 | while read ref; do git branch -m "origin/$ref" "$ref"; done

# add a remote repo
git remote add tgt $GIT_REMOTE_PATH$GITREPO.git
# push all branchs from the bare to the remote beanstalk repo
git for-each-ref --format='%(refname)' refs/heads | cut -d / -f 3 | while read ref; do git push tgt $ref; done