" Vim syntax file
" Language:             packages plugin
" Maintainer:           David le Blanc
" Latest Revision:      2017-05-18

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   PackagesInfo      '^>\@!' nextgroup=PackagesName
syn match   PackagesSpecial   '^>.*$' contains=PackagesToken
syn match   PackagesName      contained '\S\+\s\+' nextgroup=PackagesArch
syn match   PackagesArch      contained '\S\+\s\+' nextgroup=PackagesVersion
syn match   PackagesToken     contained '>' nextgroup=PackagesEssential conceal
syn match   PackagesEssential contained '\S\+\s\+' nextgroup=PackagesArch
syn match   PackagesVersion   contained '\S\+$'

hi def link PackagesName      Directory
hi def link PackagesArch      Statement
hi def link PackagesVersion   Comment
hi def link PackagesEssential SpecialKey

let b:current_syntax = "packages"

setlocal conceallevel=3
setlocal concealcursor=nv

let &cpo = s:cpo_save
unlet s:cpo_save
