" PackageMan

function! packageman#ParsePkgList(pkgs) abort
    let l:detail = {}
    let l:i = 1
    let l:hide = b:hide_removed
    call map(a:pkgs,'split(v:val,''\t'')')
    for l:pkg in a:pkgs
        if !has_key(l:detail,l:pkg[1])
            let [ l:state, l:current ] = [ tolower(l:pkg[0][0]), l:pkg[0][1] ]
            if l:hide == 1 && l:state ==? 'r' && l:current !=? 'i'
                "echo 'hiding '.l:pkg[1]
            else
                let l:mark = tolower(l:state)
                let l:deps = split(get(l:pkg,4,""),',\s*')
                call map(l:deps,'split(v:val,'' '')[0]')
                let l:detail[l:pkg[1]] = { "name": l:pkg[1], "version": l:pkg[2], "essential": l:pkg[3], "depends": l:deps, "state": l:state, "mark": l:mark, "current": l:current, "line": l:i }
                let l:i += 1
            endif
        endif
    endfor
    return l:detail
endfunction

function! packageman#LoadAvailable() abort
    " 'dpkg --get-selections *' expands the wildcard on the commandline due to some internal
    " bug.  use bash -f -c 'dpkg --get-selections *' to prevent this happening, and allow
    " the wildcard to apply to the package database instead.
    let l:avail = systemlist( "awk -F': ' 'BEGIN{cmd=\"bash -f -c \\\"dpkg --get-selections *\\\"\";while(cmd|getline){split($0,s,\" \");split(s[1],p,\":\");pkg=p[1];state[pkg]=substr(s[2],1,1);if(state[pkg]==\"d\"){state[pkg]=\"r\"}}}/^$/{if(n[\"Essential\"]==\"\"){n[\"Essential\"]=\"no\"};if(state[n[\"Package\"]]==\"\"){state[n[\"Package\"]]=\"r\"}print state[n[\"Package\"]]\"u \\t\"n[\"Package\"]\"\\t\"n[\"Version\"]\"\\t\"n[\"Essential\"]\"\\t\"n[\"Depends\"];delete n;n[\"Essential\"]=\"no\";next}{n[$1]=$2}' /var/lib/dpkg/available\|sort -k2,2" )
    return packageman#ParsePkgList(l:avail)
endfunction

function! packageman#LoadInstalled() abort
    let l:installed = systemlist("dpkg-query -W --showformat '${db:Status-Abbrev}\\t${Package}\\t${Version}\\t${Essential}\\t${Depends}\\n'")
    return packageman#ParsePkgList(l:installed)
endfunction

function! packageman#CalcDependencies() abort
    let l:deps = {}
    for l:pkg in values(b:pkgs)
        if has_key(l:pkg,'depends')
            for l:dep in l:pkg['depends']
                if has_key(l:deps,l:dep)
                    let l:deps[l:dep] += [ l:pkg['name'] ]
                else
                    let l:deps[l:dep] = [ l:pkg['name'] ]
                endif
            endfor
        endif
    endfor
    return l:deps
endfunction

function! packageman#ToggleSign(line, mark) abort
    if has_key(b:marks, a:line)
        if a:mark ==# ''
            " remove any mark
            exe 'sign unplace '.a:line.' buffer='.bufnr('%')
            call remove(b:marks,a:line)
        elseif a:mark !=# b:marks[a:line]
            " update mark
            exe 'sign unplace '.a:line
            exe 'sign place '.a:line.' name=packageman_sign_'.a:mark.' line='.a:line.' buffer='.bufnr('%')
            let b:marks[a:line] = a:mark
        endif
    else
        if a:mark !=# ''
            " set a mark
            exe 'sign place '.a:line.' name=packageman_sign_'.a:mark.' line='.a:line.' buffer='.bufnr('%')
            let b:marks[a:line] = a:mark
        endif
    endif
    return 0
endfunction

function! packageman#SetSelections() abort
    let l:out = ''
    " Record the changes here, so they arent applied unless dpkg is successful
    let l:changelog = []
    let l:pkgs = values(filter(copy(b:pkgs), 'v:val["state"] !=? v:val["mark"] && v:val["mark"] !=# "E"'))
    if len(l:pkgs) > 0
        for l:pkg in l:pkgs
            if l:pkg['mark'] ==# 'r'
                let l:out .= l:pkg['name'].' deinstall'."\n"
            elseif l:pkg['mark'] ==# 'p'
                let l:out .= l:pkg['name'].' purge'."\n"
            elseif l:pkg['mark'] ==# 'h'
                let l:out .= l:pkg['name'].' hold'."\n"
            else
                let l:out .= l:pkg['name'].' install'."\n"
            endif
            " Add the required change to the change log
            let l:changelog += [ [ l:pkg['name'], l:pkg['mark'] ] ]
        endfor
        silent let l:error = system('sudo dpkg --set-selections', l:out)
        if l:error !=# ''
            return -1
        else
            " Apply the change log
            for l:change in l:changelog
                let b:pkgs[l:change[0]]['state'] = l:change[1]
            endfor
        endif
    endif
    return len(l:pkgs)
endfunction

function! packageman#SignSelections() abort
    let l:ignored = (b:package_source ==? 'installed')? 'i' : 'r'
    let l:filtered = filter(values(b:pkgs), 'v:val["mark"] !=? v:val["state"] || v:val["state"] !=? '''.l:ignored.'''')
    for l:pkg in l:filtered
        let l:mark = l:pkg['mark']
        if l:pkg['essential'] !=? 'no'
            let l:mark = toupper(l:mark)
        endif
        if l:pkg['state'] !=? l:mark || l:pkg['state'] !=? l:ignored
            if !has_key(b:marks,l:pkg['line']) || b:marks[l:pkg['line']] !=? l:mark
                call packageman#ToggleSign(l:pkg['line'], l:mark)
            endif
        else
            call packageman#ToggleSign(l:pkg['line'], '')
        endif
    endfor
endfunction

function! s:packagemanDictSort(a,b) abort
    if a:a['line'] < a:b['line']
        return -1
    elseif a:b['line'] < a:a['line']
        return 1
    else
        return 0
    endif
endfunction

function! packageman#LoadBuffer() abort
    let l:len = sort(values(map(copy(b:pkgs),'len(v:val["name"])')),'n')[-1]
    let l:len += 4
    let l:buffer = map(sort(values(b:pkgs),
                \ function('s:packagemanDictSort')),
                \ 'printf("%-*s%s",l:len, v:val[''name''], v:val[''version''])')
    call setline(1,l:buffer)
endfunction

function! packageman#UpdateAvailable() abort
    let l:file = tempname()
    let l:availdata = systemlist('apt-cache dumpavail')
    if len(l:availdata) > 1
        call writefile(l:availdata, l:file)
        call system('dpkg --merge-avail '.l:file)
        call delete(l:file)
    endif
    echomsg "Update Complete."
endfunction

function! packageman#PackageInfo() abort
    " Get package name from current line of buffer
    let l:pkg = split(getline('.'),'\s\+')[0]
    let l:pos = line('w0')
    let l:data = b:pkgs[l:pkg]
    " Detect if preview windows closed for other reasons..
    let l:pvw = -1
    for l:nr in range(1,winnr('$'))
        if getwinvar(l:nr,'&previewwindow') == 1
            let l:pvw = l:nr
            break
        endif
    endfor

    " If preview window is open, and the current line is the same as the previous
    " then close it.
    if exists('b:last_preview') && b:last_preview == line('.') && l:pvw >= 0
        silent pclose
        unlet! b:last_preview
    else
        if l:pvw < 0
            " Open a buffer in a split to be the new preview window.
            " - '&previewheight split' to set the correct height
            " - '+buffer fnameescape()' to ensure the same buffer is reloaded into the split every time
            exe 'silent topleft '.&previewheight.'split +buffer '.fnameescape('Package Info')
            " Mark the window as an unsaved, unchangable preview window
            setlocal previewwindow
            setlocal buftype=nowrite
            setlocal filetype=help
        else
            exe l:pvw.'wincmd w'
        endif
        setlocal modifiable
        " Clear the window
        exe '%d'
        if !has_key(l:data,'packageinfo')
            echon 'Getting description for package '.l:pkg
            let l:data['packageinfo'] = systemlist('dpkg-query -W --showformat=''** *${Package}* `${Version}`\n\nDepends on ${Depends}~\n\n${Description}\n'' '.l:pkg)
        else
            echo
        endif
        if has_key(l:data,'packageinfo')
            call setline(1,l:data['packageinfo'])
        else
            call setline(1,'no package details available.')
        endif
        setlocal nomodifiable
        setlocal nomodified
        " Return to the window we came from
        wincmd p
        call winrestview({'topline':l:pos})
        let b:last_preview = line('.')
    endif
endfunction

function! packageman#Load() abort
    if exists('b:package_source') && b:package_source !=? 'installed'
        let b:pkgs = packageman#LoadAvailable()
    else
        let b:pkgs = packageman#LoadInstalled()
    endif
    let b:deps =  packageman#CalcDependencies()
    let b:marks = {}
    let b:last_mark = ''
    let b:mark_set = -1
    let b:mark_force = 0
    let b:mark_undo = []
    " b:marks is cleared so we need to ensure all existing marks are 'unplace'd
    silent exe 'sign unplace * buffer='.bufnr('%')
    setlocal modifiable
    call packageman#LoadBuffer()
    " Ensure the buffer is now read-only and won't be saved automatically when we exit
    setlocal nomodifiable
    setlocal nomodified
    setlocal iskeyword+=45-47
    call packageman#SignSelections()
endfunction

function! packageman#Commit() abort
    let l:result = packageman#SetSelections()
    if l:result == 0
        echo 'No changes.'
    elseif l:result < 0
        echo 'Error applying changes'
    else
        echo 'Applied package changes.'
    endif
    call packageman#SignSelections()
endfunction

function! packageman#Init(bang) abort
    enew
    file dpkg
    sign define packageman_sign_r text=r linehl=Exception
    sign define packageman_sign_R text=R linehl=ErrorMsg
    sign define packageman_sign_i text=i linehl=Exception
    sign define packageman_sign_I text=I linehl=NonText
    sign define packageman_sign_h text=h linehl=LineNr
    sign define packageman_sign_H text=H linehl=LineNr
    sign define packageman_sign_p text=p linehl=Exception
    sign define packageman_sign_P text=P linehl=ErrorMsg
    sign define packageman_sign_u text=u linehl=LineNr
    sign define packageman_sign_U text=U linehl=LineNr

    augroup PackageMan
        autocmd BufCreate,BufNew,BufRead,BufNewFile <buffer> call packageman#Load()
        autocmd BufWriteCmd <buffer> call packageman#Commit()
        "autocmd BufUnload <buffer> call packageman#Commit()
    augroup END

    setlocal buftype=acwrite
    let b:package_source = ( a:bang ==# '' ) ? 'installed' : 'available'

    if exists('g:packageman_hide_removed')
        let b:hide_removed = g:packageman_hide_removed
    else
        let b:hide_removed = 0
    endif

    command! -buffer PackageManView call packageman#ListMarks()
    command! -buffer -range PackageManRemove call packageman#SetMark('r',<line1>,<line2>)
    command! -buffer -range PackageManInstall call packageman#SetMark('i',<line1>,<line2>)
    command! -buffer -range PackageManPurge call packageman#SetMark('p',<line1>,<line2>)
    command! -buffer -range PackageManHold call packageman#SetMark('h',<line1>,<line2>)
    command! -buffer -range PackageManRepeat call packageman#RepeatMark(<line1>,<line2>)
    command! -buffer PackageManPurgeAll call packageman#PurgeAll()
    command! -buffer PackageManRefresh call packageman#UpdateAvailable()
    command! -buffer PackageManExecute call packageman#Execute()
    command! -buffer PackageManPrevMark call packageman#PrevMark()
    command! -buffer PackageManNextMark call packageman#NextMark()
    command! -buffer PackageManUndo call packageman#Undo()
    command! -buffer PackageManInfo call packageman#PackageInfo()

    nnoremap <silent> <buffer> D :PackageManRemove<CR>
    nnoremap <silent> <buffer> R :PackageManRemove<CR>
    nnoremap <silent> <buffer> P :PackageManPurge<CR>
    nnoremap <silent> <buffer> I :PackageManInstall<CR>
    nnoremap <silent> <buffer> H :PackageManHold<CR>
    nnoremap <silent> <buffer> V :PackageManView<CR>
    nnoremap <silent> <buffer> E :PackageManExecute<CR>
    nnoremap <silent> <buffer> u :PackageManUndo<CR>
    nnoremap <silent> <buffer> U :PackageManUndo<CR>
    nnoremap <silent> <buffer> <Space> :PackageManRepeat<CR>

    nnoremap <silent> <buffer> [s :PackageManPrevMark<CR>
    nnoremap <silent> <buffer> ]s :PackageManNextMark<CR>
    nnoremap <silent> <buffer> [c :PackageManPrevMark<CR>
    nnoremap <silent> <buffer> ]c :PackageManNextMark<CR>

    nnoremap <silent> <buffer> h :PackageManInfo<CR>
    nnoremap <silent> <buffer> <Leader>P :PackageManPurgeAll<CR>

    nnoremap <silent> <buffer> <F1> :help packageman-bindings<CR>

    vnoremap <silent> <buffer> D :PackageManRemove<CR>
    vnoremap <silent> <buffer> R :PackageManRemove<CR>
    vnoremap <silent> <buffer> P :PackageManPurge<CR>
    vnoremap <silent> <buffer> I :PackageManInstall<CR>
    vnoremap <silent> <buffer> H :PackageManHold<CR>

    " Setting filetype triggers immediate autocommands
    setlocal filetype=packages
endfunction


function! packageman#RepeatMark(start,end) abort
    if exists('b:last_mark') && b:last_mark !=# ''
        call packageman#MarkRange(b:last_mark,a:start,a:end)
        call cursor(a:end+1,col('.'))
    endif
endfunction

function! packageman#SetMark(mark,start,end) abort
    let b:mark_set = -1
    let b:mark_force = 0
    return packageman#MarkRange(a:mark,a:start,a:end)
endfunction

function! packageman#MarkRange(mark,start,end) abort
    let l:undo = []
    let l:line = a:start
    let b:last_mark = a:mark
    let l:count = 0
    while l:line <= a:end
        let l:pkg = split(getline(l:line),'\s\+')[0]
        if b:mark_set < 0
            if b:pkgs[l:pkg]['essential'] !=? 'no'
                let b:mark_force = 1
            endif
            let b:mark_set = b:pkgs[l:pkg]['mark'] !=? a:mark
        endif
        if b:pkgs[l:pkg]['essential'] ==? 'no' || b:mark_force
            let l:new_mark = b:mark_set ? a:mark : b:pkgs[l:pkg]['state']
            if !b:mark_set && l:new_mark == a:mark
                if l:new_mark ==? 'p'
                    let l:new_mark = 'r'
                elseif l:new_mark ==? 'h' || l:new_mark ==? 'd'
                    let l:new_mark = 'i'
                endif
            endif
            if l:new_mark !=? b:pkgs[l:pkg]['mark']
                let l:undo += [ [ l:pkg, b:pkgs[l:pkg]['mark'] ] ]
                let b:pkgs[l:pkg]['mark'] = l:new_mark
                let l:count += 1
                if has_key(b:deps, l:pkg) && a:mark ==? 'r' && b:mark_set
                    let l:deps = b:deps[l:pkg]
                    for l:dep in l:deps
                        if has_key(b:pkgs,l:dep)
                            if b:pkgs[l:dep]['mark'] !=? a:mark
                                let l:undo += [ [ l:dep, b:pkgs[l:dep]['mark'] ] ]
                                let b:pkgs[l:dep]['mark'] = a:mark
                                let l:count += 1
                            endif
                        endif
                    endfor
                elseif has_key(b:pkgs[l:pkg],'depends') && a:mark ==? 'i' && b:mark_set
                    let l:deps = b:pkgs[l:pkg]['depends']
                    for l:dep in l:deps
                        if has_key(b:pkgs,l:dep)
                            if b:pkgs[l:dep]['mark'] !=? a:mark
                                let l:undo += [ [ l:dep, b:pkgs[l:dep]['mark'] ] ]
                                let b:pkgs[l:dep]['mark'] = a:mark
                                let l:count += 1
                            endif
                        endif
                    endfor
                endif
            endif
        endif
        let l:line+=1
    endwhile
    if len(l:undo) > 0
        let b:mark_undo += [ [[ line('.'),col('.') ]] + l:undo ]
    endif
    if l:count > 1
        echo l:count.' packages marked.'
    else
        echo
    endif
    call packageman#SignSelections()
endfunction

function! packageman#ListMarks() abort
    let l:out = ''
    let l:list = values(filter(copy(b:pkgs),'v:val["state"] !=# v:val["mark"] && v:val["mark"] !=# "E"'))
    "let l:len = sort(map(copy(l:list),'len(v:val["name"])'),'n')[-1]
    for l:pkg in l:list
        "let l:out .= printf("%-*s %s\n", l:len, l:pkg['name'],l:pkg['mark'][0])
        let l:out .= printf("%s %s\n", l:pkg['mark'][0], l:pkg['name'])
    endfor
    echo l:out
endfunction

function! packageman#PurgeAll() abort
    for l:pkg in values(b:pkgs)
        if l:pkg['state'] ==? 'r' && l:pkg['mark'] ==? 'r'
            let l:pkg['mark'] = 'p'
        endif
    endfor
    call packageman#SignSelections()
endfunction

function! packageman#Execute() abort
    if packageman#SetSelections() > 0
        call packageman#SignSelections()
        exe '!sudo apt-get dselect-upgrade'
    endif
    redraw!
endfunction

function! packageman#PrevMark() abort
    let l:line = line('.')
    let l:col = col('.')
    let l:marks = sort(filter(map(keys(b:marks),'v:val + 0'),'v:val < '.l:line),'n')
    while !empty(l:marks) && l:marks[-1] == l:line-1
        let l:line = l:marks[-1]
        call remove(l:marks,-1)
    endwhile
    if !empty(l:marks)
        let l:line=l:marks[-1]
        call cursor(l:line,l:col)
    endif
endfunction

function! packageman#NextMark() abort
    let l:line = line('.')
    let l:col = col('.')
    let l:marks = sort(filter(map(keys(b:marks),'v:val + 0'),'v:val > '.l:line),'n')
    while !empty(l:marks) && l:marks[0] == l:line+1
        let l:line = l:marks[0]
        call remove(l:marks,0)
    endwhile
    if !empty(l:marks)
        let l:line=l:marks[0]
        call cursor(l:line,l:col)
    endif
endfunction

function! packageman#Undo() abort
    if len(b:mark_undo) == 0
        echo "Already at oldest change"
    else
        let l:undo = b:mark_undo[-1]
        call remove(b:mark_undo,-1)
        let l:pos = l:undo[0]
        for l:fix in l:undo[1:]
            let b:pkgs[l:fix[0]]['mark'] = l:fix[1]
        endfor
        call cursor(l:pos[0],l:pos[1])
    endif
    call packageman#SignSelections()
endfunction
