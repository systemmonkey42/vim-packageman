" Vim syntax file
" Language:             packages plugin
" Maintainer:           David le Blanc
" Latest Revision:      2017-05-18

if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match   packagesInfo    '^\S\+\s\+\S\+$' contains=packagesName,packagesVersion
syn match   packagesName    contained '^\S\+\ze\s\+' nextgroup=packagesVersion
syn match   packagesVersion contained '\S\+$'

hi def link packagesName    Directory
hi def link packagesVersion Comment

let b:current_syntax = "packages"

let &cpo = s:cpo_save
unlet s:cpo_save
