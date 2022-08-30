#!/bin/bash

RELEASE_NOTE="Test"


git status
if [ "$(git status --porcelain)" ]; then
    echo "There are uncommited files"
    echo "Enter Commit Message"
    read commitMessage
    git add .
    git commit -m "$commitMessage"
    git tag v3.04 -m "$RELEASE_NOTE" || echo "the tag already exists"
    git push origin v3.04
    gh release create v3.04

    else
    git add .
    git commit -m "No Changes"
    git push origin
fi
