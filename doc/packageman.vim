" PackageMan

function! packageman#ParsePkgList(pkgs) abort
    let l:detail = {}
    let l:i = 1

    call map(a:pkgs,'split(v:val,''\t'')')
    for l:pkg in a:pkgs
        let l:deps = split(get(l:pkg,4,""),',\s*')
        let [ l:state, l:current ] = [ tolower(l:pkg[0][0]), l:pkg[0][1] ]
        let l:mark = tolower(l:state)
        call map(l:deps,'split(v:val,'' '')[0]')
        let l:detail[l:pkg[1]] = { "name": l:pkg[1], "version": l:pkg[2], "essential": l:pkg[3], "depends": l:deps, "state": l:state, "mark": l:mark, "current": l:current, "line": l:i }
        let l:i += 1
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

function! packageman#ToggleSign(line, mark)
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

function! packageman#SetSelections()
    let l:out = ''
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
            let b:pkgs[l:pkg['name']]['state'] = l:pkg['mark']
        endfor
        silent call system('sudo dpkg --set-selections', l:out)
    endif
    return len(l:pkgs)
endfunction

function! packageman#SignSelections() abort
    nnoremap <silent> <buffer> D :PackageManRemove<CR>
    let l:ignored = (b:package_source ==? 'installed')? 'i' : 'r'
    for l:pkg in values(b:pkgs)
        let l:mark = l:pkg['mark']
        if l:pkg['essential'] !=? 'no'
            let l:mark = toupper(l:mark)
        endif
        if l:pkg['state'] !=? l:mark || l:pkg['state'] !=? l:ignored
            call packageman#ToggleSign(l:pkg['line'], l:mark)
        else
            call packageman#ToggleSign(l:pkg['line'], '')
        endif
    endfor
endfunction

function! packageman#LoadBuffer() abort
    let l:len = sort(values(map(copy(b:pkgs),'len(v:val["name"])')),'n')[-1]
    let l:buffer = []
    for l:pkg in values(b:pkgs)
        let [ l:line,l:name,l:ver ] = [ l:pkg["line"], l:pkg["name"], l:pkg["version"] ]
        while len(l:buffer) < l:line
            let l:buffer += ["~~"]
        endwhile
        let l:buffer[l:line-1] = printf("%-*s%s",l:len+4,l:name,l:ver) 
    endfor
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

    " b:marks is cleared, purge existing marks
    silent exe 'sign unplace * buffer='.bufnr('%')
    setlocal modifiable
    call packageman#LoadBuffer()
    setlocal nomodifiable
    call packageman#SignSelections()
endfunction

function! packageman#Commit()
    call packageman#SetSelections()
endfunction

function! packageman#Init(bang)
    enew
    file dpkg
    sign define packageman_sign_r text=r linehl=Exception
    sign define packageman_sign_R text=R linehl=ErrorMsg
"    sign define packageman_sign_X text=D linehl=ErrorMsg
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
        autocmd BufUnload <buffer> call packageman#Commit()
    augroup END

    setlocal buftype=nofile
    let b:package_source = ( a:bang ==# '' ) ? 'installed' : 'available'

    nnoremap <silent> <buffer> D :PackageManRemove<CR>
    nnoremap <silent> <buffer> R :PackageManRemove<CR>
    nnoremap <silent> <buffer> P :PackageManPurge<CR>
    nnoremap <silent> <buffer> I :PackageManInstall<CR>
    nnoremap <silent> <buffer> H :PackageManHold<CR>
    nnoremap <silent> <buffer> V :PackageManView<CR>
    nnoremap <silent> <buffer> E :PackageManExecute<CR>
    nnoremap <silent> <buffer> u :PackageManUndo<CR>
    nnoremap <silent> <buffer> U :PackageManUndo<CR>
    nnoremap <silent> <buffer> [s :PackageManPrevMark<CR>
    nnoremap <silent> <buffer> ]s :PackageManNextMark<CR>
    nnoremap <silent> <buffer> [c :PackageManPrevMark<CR>
    nnoremap <silent> <buffer> ]c :PackageManNextMark<CR>
    nnoremap <silent> <buffer> <Space> :PackageManRepeat<CR>
    nnoremap <silent> <buffer> <Leader>P :PackageManPurgeAll<CR>

    vnoremap <silent> <buffer> D :PackageManRemove<CR>
    vnoremap <silent> <buffer> R :PackageManRemove<CR>
    vnoremap <silent> <buffer> P :PackageManPurge<CR>
    vnoremap <silent> <buffer> I :PackageManInstall<CR>
    vnoremap <silent> <buffer> H :PackageManHold<CR>

    " Setting filetype triggers immediate autocommands
    setlocal filetype=packages
endfunction

augroup PackageMan
    autocmd!
    autocmd Filetype packages nested call packageman#Load()
augroup END

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
            if l:new_mark !=? b:pkgs[l:pkg]['mark']
                let l:undo += [ [ l:pkg, b:pkgs[l:pkg]['mark'] ] ]
                let b:pkgs[l:pkg]['mark'] = l:new_mark
                let l:count += 1
                if has_key(b:deps, l:pkg) && a:mark ==? 'r' && b:mark_set
                    let l:deps = b:deps[l:pkg]
                    for l:dep in l:deps
                        if b:pkgs[l:dep]['mark'] !=? a:mark
                            let l:undo += [ [ l:dep, b:pkgs[l:dep]['mark'] ] ]
                            let b:pkgs[l:dep]['mark'] = a:mark
                            let l:count += 1
                        endif
                    endfor
                elseif has_key(b:pkgs[l:pkg],'depends') && a:mark ==? 'i' && b:mark_set
                    let l:deps = b:pkgs[l:pkg]['depends']
                    for l:dep in l:deps
                        if b:pkgs[l:dep]['mark'] !=? a:mark
                            let l:undo += [ [ l:dep, b:pkgs[l:dep]['mark'] ] ]
                            let b:pkgs[l:dep]['mark'] = a:mark
                            let l:count += 1
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
    endif
    call packageman#SignSelections()
endfunction

function! packageman#ListMarks()
    let l:out = ''
    let l:list = values(filter(copy(b:pkgs),'v:val["state"] !=# v:val["mark"] && v:val["mark"] !=# "E"'))
    "let l:len = sort(map(copy(l:list),'len(v:val["name"])'),'n')[-1]
    for l:pkg in l:list
        "let l:out .= printf("%-*s %s\n", l:len, l:pkg['name'],l:pkg['mark'][0])
        let l:out .= printf("%s %s\n", l:pkg['mark'][0], l:pkg['name'])
    endfor
    echo l:out
endfunction

function! packageman#PurgeAll()
    for l:pkg in values(b:pkgs)
        if l:pkg['state'] ==? 'r' && l:pkg['mark'] ==? 'r'
            let l:pkg['mark'] = 'p'
        endif
    endfor
    call packageman#SignSelections()
endfunction

function! packageman#Execute()
    if packageman#SetSelections()
        call packageman#SignSelections()
        "echo 'apt-get dselect-update'
    endif
endfunction

function! packageman#PrevMark()
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

function! packageman#NextMark()
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

function! packageman#Undo()
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

command! -bang PackageMan call packageman#Init("<bang>")
command! PackageManView call packageman#ListMarks()
command! -range PackageManRemove call packageman#SetMark('r',<line1>,<line2>)
command! -range PackageManInstall call packageman#SetMark('i',<line1>,<line2>)
command! -range PackageManPurge call packageman#SetMark('p',<line1>,<line2>)
command! -range PackageManHold call packageman#SetMark('h',<line1>,<line2>)
command! -range PackageManRepeat call packageman#RepeatMark(<line1>,<line2>)
command! PackageManPurgeAll call packageman#PurgeAll()
command! PackageManExecute call packageman#Execute()
command! PackageManPrevMark call packageman#PrevMark()
command! PackageManNextMark call packageman#NextMark()
command! PackageManUndo call packageman#Undo()
