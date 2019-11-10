let s:ch = -1
let s:connected = 0

let s:plugin_root = expand('<sfile>:p:h:h')
let s:pid_path = s:plugin_root . '/.alive'

function! prets#server_alive() abort
  return filereadable(s:pid_path)
endfunction

function! prets#enable() abort
  if !prets#server_alive()
    call prets#start_server()
  endif
  call timer_start(300, {_ -> prets#connect(0)})
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

function! prets#connect(n_tries) abort
  if a:n_tries >= 3
    echoerr '[vim-prets] Could not connect to Prets server'
  endif

  let s:ch = ch_open('localhost:4242', {'mode': 'json'})
  if ch_status(s:ch) == 'open'
    let s:connected = 1
  else
    call timer_start(300, {_ -> prets#connect(a:n_tries + 1)})
  endif
endfunction

function! prets#format_sync() abort
  let filepath = expand('%:p')
  let src = join(getline(1, '$'), "\n")

  " Send a whole text and make the server return the formatted version.
  " This is much faster than change the target file externally by `prettier -w [filename]`.
  let res = ch_evalexpr(s:ch, {
    \   'bufnr': bufnr('%'),
    \   'source': src,
    \   'path':filepath,
    \ })
  call prets#_on_response(s:ch, res)
endfunction

function prets#_on_response(_ch, res)
  let lines = split(a:res.source, "\n")
  let first_line_to_remove = len(lines) + 1
  let bufnr = a:res.bufnr
  let cur_buf = bufnr('%')

  call setbufline(bufnr, 1, lines)
  call deletebufline(bufnr, first_line_to_remove, '$')

  noautocmd write
endfunction


function prets#format_on_save() abort
  if !s:connected
    return
  endif
  call prets#format_sync()
endfunction

" Formatter function for ALE.
" https://github.com/dense-analysis/ale
function prets#ale(bufnr, lines) abort
  let filepath = expand('%:p')
  let src = join(a:lines, "\n")
  let res = ch_evalexpr(s:ch, {
    \   'bufnr': a:bufnr,
    \   'source': src,
    \   'path':filepath,
    \ })
  return split(res.source, "\n")
endfunction
