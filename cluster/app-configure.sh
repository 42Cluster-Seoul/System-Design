#!/bin/bash

## git access key
echo <access key> > ~/.ssh/gh-key
cat ~/.ssh/gh-key >> .git-credentials
git config credential.helper store --global

## cli
git config --global user.name seongtaekkim
git config --global user.email "chxortnl@gmail.com"

## gh login & 
gh auth login --with-token < ~/.ssh/gh-key
gh repo clone 42Cluster-Seoul/operator
cd operator
export BASE_OPT=$(pwd)
export HIST=opt-history
sh cluster-init.sh