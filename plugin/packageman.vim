" PackageMan

command! -bang PackageMan call packageman#Init("<bang>")
command! -bang PackageManRefresh call packageman#UpdateAvailable("<bang>")
