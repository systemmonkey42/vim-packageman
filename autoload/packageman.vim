" PackageMan

function! packageman#ParsePkgList(pkgs) abort
    let l:pkgs = []
    let l:ref = {}
    let l:hide = b:hide_removed
    call map(map(a:pkgs,'split(v:val,''\t'')'), '{
                \ "name":v:val[0],
                \ "version":v:val[2],
                \ "essential":v:val[3],
                \ "depends":map(split(get(v:val,4,''''),'',\s*''),''split(v:val,'''' '''')[0]''),
                \ "state":tolower(v:val[1][0]),
                \ "current":v:val[1][1],
                \ "mark":tolower(v:val[1][0]),
                \ "line": 0}'
                \ )

    let l:i = 0
    for l:pkg in a:pkgs
        if l:hide == 1 && l:pkg["state"] ==? 'r' && l:pkg["current"] !=? 'i'
            "echo 'hiding '.l:pkg[1]
        else
            let l:ref[l:pkg["name"]] = l:i
            let l:pkgs += [ l:pkg ]
            let l:i += 1
            let l:pkg["line"] = l:i
        endif
    endfor
    return [ l:pkgs, l:ref ]
endfunction

function! packageman#LoadAvailable() abort
    " 'dpkg --get-selections *' expands the wildcard on the commandline due to some internal
    " bug.  use bash -f -c 'dpkg --get-selections *' to prevent this happening, and allow
    " the wildcard to apply to the package database instead.
    let l:avail = systemlist( "awk -F': ' 'BEGIN{cmd=\"bash -f -c \\\"dpkg --get-selections *\\\"\";while(cmd|getline){split($0,s,\" \");split(s[1],p,\":\");pkg=p[1];state[pkg]=substr(s[2],1,1);if(state[pkg]==\"d\"){state[pkg]=\"r\"}}}/^$/{if(n[\"Essential\"]==\"\"){n[\"Essential\"]=\"no\"};if(state[n[\"Package\"]]==\"\"){state[n[\"Package\"]]=\"r\"}if(n[\"Package\"]!=prev){print n[\"Package\"]\"\\t\"state[n[\"Package\"]]\"u \\t\"n[\"Version\"]\"\\t\"n[\"Essential\"]\"\\t\"n[\"Depends\"];prev=n[\"Package\"]};delete n;n[\"Essential\"]=\"no\";next}{n[$1]=$2}' /var/lib/dpkg/available\|sort" )
    return packageman#ParsePkgList(l:avail)
endfunction

function! packageman#LoadInstalled() abort
    let l:installed = systemlist("dpkg-query -W --showformat '${Package}\\t${db:Status-Abbrev}\\t${Version}\\t${Essential}\\t${Depends}\\n'")
    return packageman#ParsePkgList(l:installed)
endfunction

function! packageman#CalcDependencies() abort
    let l:deps = map(copy(b:ref),'[]')
    for l:pkg in b:pkgs
        for l:dep in l:pkg['depends']
            if has_key(l:deps,l:dep)
                let l:deps[l:dep] += [ l:pkg['name'] ]
            endif
        endfor
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

function! packageman#SignSelections(...) abort
    let l:ignored = (b:package_source ==? 'installed')? 'i' : 'r'
    let l:filtered = filter(copy(b:pkgs), 'v:val["mark"] !=? v:val["state"] || v:val["state"] !=? '''.l:ignored.''' || (has_key(b:marks,v:val["line"]) && get(v:val,"mark") !=# b:marks[v:val["line"]])')
    for l:pkg in l:filtered
        let l:mark = l:pkg['mark']
        if l:pkg['essential'] !=? 'no'
            let l:mark = toupper(l:mark)
        endif
        if l:pkg['state'] !=? l:mark || l:pkg['state'] !=? l:ignored
            if !has_key(b:marks,l:pkg['line']) || get(b:marks,l:pkg['line'],'') !=? l:mark
                call packageman#ToggleSign(l:pkg['line'], l:mark)
            endif
        else
            call packageman#ToggleSign(l:pkg['line'], '')
        endif
    endfor
endfunction

function! packageman#LoadBuffer() abort
    let l:len = max(map(copy(b:pkgs),'len(v:val["name"])')) + 4
    let l:buffer = map(copy(b:pkgs),'printf("%-*s%s",l:len, v:val[''name''], v:val[''version''])')
    return setline(1,l:buffer)
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
    let l:pos = line('w0')
    let l:data = b:pkgs[line('.')-1]
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
            let l:pkg = l:data['name']
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
        let [ b:pkgs, b:ref ] = packageman#LoadAvailable()
    else
        let [ b:pkgs, b:ref ] = packageman#LoadInstalled()
    endif
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
    if has('timers')
        call timer_start(1000,function('packageman#SignSelections'))
    else
        call packageman#SignSelections()
    endif
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
    nnoremap <silent> <buffer> d :PackageManRemove<CR>
    nnoremap <silent> <buffer> R :PackageManRemove<CR>
    nnoremap <silent> <buffer> r :PackageManRemove<CR>
    nnoremap <silent> <buffer> P :PackageManPurge<CR>
    nnoremap <silent> <buffer> I :PackageManInstall<CR>
    nnoremap <silent> <buffer> i :PackageManInstall<CR>
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
    vnoremap <silent> <buffer> d :PackageManRemove<CR>
    vnoremap <silent> <buffer> R :PackageManRemove<CR>
    vnoremap <silent> <buffer> r :PackageManRemove<CR>
    vnoremap <silent> <buffer> P :PackageManPurge<CR>
    vnoremap <silent> <buffer> I :PackageManInstall<CR>
    vnoremap <silent> <buffer> i :PackageManInstall<CR>
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
    if !exists('b:deps')
        let b:deps =  packageman#CalcDependencies()
    endif
    return packageman#MarkRange(a:mark,a:start,a:end)
endfunction

function! packageman#MarkRange(mark,start,end) abort
    let l:undo = []
    let l:line = a:start
    let b:last_mark = a:mark
    let l:count = 0
    let l:error = ''
    while l:line <= a:end && l:error ==# ''
        let l:pkg = b:pkgs[l:line-1]
        if b:mark_set < 0
            if l:pkg['essential'] !=? 'no'
                let b:mark_force = 1
            endif
            let b:mark_set = l:pkg['mark'] !=? a:mark
        endif
        let l:new_mark = b:mark_set ? a:mark : l:pkg['state']
        " if !b:mark_set && l:new_mark == a:mark
        "     if l:new_mark ==? 'p'
        "         let l:new_mark = 'r'
        "     elseif l:new_mark ==? 'h' || l:new_mark ==? 'r'
        "         let l:new_mark = 'i'
        "     endif
        " endif
        if l:pkg['essential'] ==? 'no' || b:mark_force
            if l:new_mark !=? l:pkg['mark']
                if has_key(b:deps, l:pkg['name']) && l:new_mark ==? 'r' && b:mark_set
                    let l:deps = [ l:pkg['name'] ]
                    while len(l:deps) > 0 && l:error ==# ''
                        let l:cur = remove(l:deps,0)
                        if has_key(b:ref,l:cur)
                            let l:x = b:ref[l:cur]
                            if b:pkgs[l:x]['mark'] !=? l:new_mark
                                if b:pkgs[l:x]['essential'] ==? 'no' || b:mark_force
                                    let l:undo += [ [ l:x, b:pkgs[l:x]['mark'] ] ]
                                    let b:pkgs[l:x]['mark'] = l:new_mark
                                    let l:count += 1
                                    if has_key(b:deps,l:cur)
                                        let l:deps += b:deps[l:cur]
                                    endif
                                else
                                    let l:error = l:cur
                                endif
                            endif
                        endif
                    endwhile
                elseif has_key(b:pkgs[l:line-1],'depends') && l:new_mark ==? 'i'
                    let l:deps = [ l:pkg['name'] ]
                    while len(l:deps) > 0 && l:error ==# ''
                        let l:cur = l:deps[0]
                        call remove(l:deps,0)
                        if has_key(b:ref,l:cur)
                            let l:x = b:ref[l:cur]
                            if b:pkgs[l:x]['mark'] !=? l:new_mark
                                let l:undo += [ [ l:x, b:pkgs[l:x]['mark'] ] ]
                                let b:pkgs[l:x]['mark'] = l:new_mark
                                let l:count += 1
                                if has_key( b:pkgs[l:x],'depends' )
                                    let l:deps += b:pkgs[l:x]['depends']
                                endif
                            endif
                        endif
                    endwhile
                else
                    let l:undo += [ [ l:line-1, l:pkg['mark'] ] ]
                    let l:pkg['mark'] = l:new_mark
                    let l:count += 1
                endif
            endif
        endif
        let l:line+=1
    endwhile
    if len(l:undo) > 0
        if l:error !=# ''
            call packageman#UndoChange(l:undo)
            let l:count = 0
            echo 'Failed to mark packages. '.l:error.' is an essential package.'
        else
            let b:mark_undo += [ [[ line('.'),col('.') ]] + l:undo ]
        endif
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
    let l:list = filter(copy(b:pkgs),'v:val["state"] !=# v:val["mark"] && v:val["mark"] !=# "E"')
    for l:pkg in l:list
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

function! packageman#UndoChange(change) abort
    for l:fix in a:change
        let b:pkgs[l:fix[0]]['mark'] = l:fix[1]
    endfor
endfunction

function! packageman#Undo() abort
    if len(b:mark_undo) == 0
        echo "Already at oldest change"
    else
        let l:undo = remove(b:mark_undo,-1)
        let l:pos = remove(l:undo,0)
        call packageman#UndoChange(l:undo)
        call cursor(l:pos[0],l:pos[1])
        call packageman#SignSelections()
    endif
endfunction
