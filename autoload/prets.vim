let s:ch = -1
let s:connected = 0

let s:plugin_root = expand('<sfile>:p:h:h')
let s:pid_path = s:plugin_root . '/.alive'

function! prets#server_alive() abort
  return filereadable(s:pid_path)
endfunction

function! prets#enable_for(filetypes) abort
  " When user opens Vim by specifing a file, enable Prets immediately
  " (FileType event does not be fired in this case).
  if &filetype != '' && index(a:filetypes, &filetype) >= 0
    call prets#enable()
  endif

  let names = join(a:filetypes, ',')
  execute 'autocmd FileType' names 'call prets#enable()'
endfunction

function! prets#enable() abort
  if s:connected
    return
  endif
  if !prets#server_alive()
    call prets#start_server()
  endif
  call timer_start(300, {_ -> prets#connect_async(10)})
endfunction

function! prets#disable() abort
  if s:connected
    let s:connected = 0
  endif
  call prets#disconnect()
endfunction

function! prets#start_server() abort
  call system("npm run start --prefix " . s:plugin_root . "&")
endfunction

function! prets#stop_server() abort
  if !prets#server_alive()
    return
  endif
  let pid = readfile(s:pid_path)[0]

  " TODO: How to do this in Windows?
  call system("kill -s SIGINT " . pid)
endfunction

function! prets#disconnect() abort
  call ch_sendexpr(s:ch, {'cmd': 'KILL'})
endfunction

function! prets#connect_async(n_tries) abort
  if a:n_tries <= 0
    echoerr '[vim-prets] Could not connect to Prets server'
    return
  endif
  if s:connect_to_server()
    let s:connected = 1
  else
    call timer_start(300, {_ -> prets#connect_async(a:n_tries - 1)})
  endif
endfunction

function! prets#connect_sync(max_tries) abort
  let n_tries = 0
  while 1
    if s:connect_to_server()
      let s:connected = 1
      break
    endif
    let n_tries += 1
    if n_tries >= a:max_tries
      echoerr '[vim-prets] Could not connect to Prets server (tried ' . n_tries . ' times)'
      return 0
    endif

    sleep 300m
  endwhile

  return 1
endfunction

function s:connect_to_server() abort
  let s:ch = ch_open('localhost:4242', {'mode': 'json'})
  return ch_status(s:ch) == 'open'
endfunction

function! s:format_sync(lines) abort
  let filepath = expand('%:p')
  let src = join(a:lines, "\n")

  " Send a whole text and make the server return the formatted version.
  " This is much faster than change the target file externally by `prettier -w [filename]`.
  return ch_evalexpr(s:ch, {
    \   'bufnr': bufnr('%'),
    \   'source': src,
    \   'path':filepath,
    \ })
endfunction

function prets#format_sync() abort
  if !s:connected
    return
  endif

  let res = s:format_sync(getline(1, '$'))
  if has_key(res, 'source')
    call s:replace_buffer_content(res)
  else
    let msg = get(res, 'message', 'unexpected error occurred')
    echoerr msg
  endif
endfunction

function s:replace_buffer_content(res)
  let lines = split(a:res.source, "\n")
  let first_line_to_remove = len(lines) + 1
  let bufnr = a:res.bufnr
  let cur_buf = bufnr('%')

  call setbufline(bufnr, 1, lines)
  call deletebufline(bufnr, first_line_to_remove, '$')

  noautocmd write
endfunction

" Formatter function for ALE.
" https://github.com/dense-analysis/ale
function prets#ale(bufnr, lines) abort
  if !s:connected
    return
  endif

  if !prets#server_alive()
    echom 'Prets server has stoped unexpectedly. Reconnecting...'
    call prets#start_server()
    call prets#connect_sync(10)
  endif

  let res = s:format_sync(a:lines)
  if type(res) != 4
    echoerr 'unexpected response from server'
    echoerr res
    return
  endif

  if has_key(res, 'source')
    return split(res.source, "\n")
  endif

  let msg = get(res, 'message', 'unexpected error occurred')
  for m in split(msg, "\n")
    echoerr m
  endfor
endfunction
