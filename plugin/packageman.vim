" PackageMan

augroup PackageMan
    autocmd!
    autocmd Filetype packages nested call packageman#Load()
augroup END

command! -bang PackageMan call packageman#Init("<bang>")
