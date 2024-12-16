function anydiff {
    Get-ChildItem -File -Recurse |
    Select-String -Pattern '^(<<<<<<<|>>>>>>>)\b' |
    Format-Table -Autosize
}
function conflicts {
    git status --porcelain | % { if ($_.StartsWith('UU ')) { sublime $_.Substring(3) } }
}
function Remove-GitUntrackedFiles {
    param(
        [Switch]$Recycle
    )

    $shell = New-Object -ComObject "Shell.Application"

    git status --porcelain | % {
        if ($_.StartsWith('?? ')) {
            $file = $_.Substring(3)
            if ($Recycle) {
                 $folder = $shell.Namespace([IO.Path]::GetDirectoryName($file))
                 $item = $folder.ParseName([IO.Path]::GetFileName($file))
                 $item.InvokeVerb("Delete")
            }
            else { rm -Confirm:$false -Recurse $file }
        }
    }
}

function g {
    git status $args
    git lg -1
}
function gaca { git add -A; if ($?) { git commit --amend @args } }
function gacan { gaca --no-edit $args }
function gcan { git commit --amend --no-edit @args }
function gb { git branch $args; git lg -1 }
function grc { git add -A; if ($?) { git rebase --continue } }
function gpf { git push --force-with-lease @args }

function gco {
    #todo: take advantage of PoshGit

    begin {
        $branchName = $args[0] #$PsBoundParameters['branch']
    }

    process {
        git checkout $branchName ($args | select -skip 1)
        if ($?) {
            git lg -1;
        }
    }
}

function grco {
    Param(
        [string]$Remote = 'origin',
        [string]$Branch = 'main',
        [Parameter(Mandatory=$true,Position=0)]
        [string]$CheckoutAs,
        [switch]$Stash
    )

    if ($Stash) {
        git stash # use create/store?
    }

    git fetch --no-tags $Remote $Branch # $rest args ?
    if ($?) { git checkout -b $CheckoutAs --track "$($Remote)/$($Branch)" }

    if ($Stash) {
        git stash pop
    }

    git lg -1

    #-b vs -B (create vs overwrite)
    # git checkout -b $CheckoutAs --guess "$Remote/$Branch" ?
}

function glr {
    Param(
        [string]$Remote = 'origin',
        [string]$Branch = 'main'
    )

    git pull -r $Remote $Branch
}