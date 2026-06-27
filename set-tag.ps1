<#
.SYNOPSIS
    (Re)create a git tag at HEAD and push it.
.DESCRIPTION
    Removes the remote tag if it exists, removes the local tag if it exists,
    then creates the tag at the current HEAD and pushes it to origin.
.PARAMETER Tag
    The tag name (e.g. v1 or v1.0.0).
.EXAMPLE
    ./set-tag.ps1 v1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Tag
)

$ErrorActionPreference = 'Stop'

# Remove the remote tag if it exists
if (git ls-remote --tags origin "refs/tags/$Tag") {
    Write-Host "Deleting remote tag '$Tag'..."
    git push origin ":refs/tags/$Tag"
} else {
    Write-Host "Remote tag '$Tag' not found; skipping."
}

# Remove the local tag if it exists
if (git tag --list $Tag) {
    Write-Host "Deleting local tag '$Tag'..."
    git tag -d $Tag
} else {
    Write-Host "Local tag '$Tag' not found; skipping."
}

# Create and push the new tag at HEAD
Write-Host "Creating tag '$Tag' at HEAD..."
git tag $Tag

Write-Host "Pushing tag '$Tag'..."
git push origin $Tag

Write-Host "Done. '$Tag' -> $(git rev-parse --short $Tag)"
