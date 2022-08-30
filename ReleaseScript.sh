#!/bin/bash

RELEASE_NOTE="Test"
TAG=${TAG}

git status
if [ "$(git status --porcelain)" ]; then
    echo "There are uncommited files"
    echo "Enter Commit Message"
    read commitMessage
    git add .
    git commit -m "$commitMessage"
    git tag "$TAG" -m "$RELEASE_NOTE" || echo "the tag already exists"
    git push origin "$TAG"
    gh release create "$TAG"

    else
    git add .
    git commit -m "No Changes"
    git push origin
fi
