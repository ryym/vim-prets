let s:ch = -1
let s:connected = 0
let s:is_auto_save = 0

function! prets#hoge() abort
  echo "hoge"
endfunction

function! prets#connect() abort
  let s:ch = ch_open('localhost:4242', {'mode': 'json'})
  let s:connected = 1
endfunction

function! prets#request_format() abort
  let filepath = expand('%:p')
  let src = join(getline(1, '$'), "\n")
  let s:cur_pos = getcurpos()
  call ch_sendexpr(s:ch, {
    \   'source': src,
    \   'path':filepath,
    \ }, {
    \   'callback': funcref('prets#_on_response'),
    \ })
endfunction

function prets#_on_response(_ch, res)
  let lines = split(a:res.source, "\n")
  execute '1,$delete'
  call setline(1, lines)
  call cursor(s:cur_pos[1:])

  let s:is_auto_save = 1
  execute 'write'
  let s:is_auto_save = 0
endfunction

function prets#format_on_save() abort
  if !s:connected
    call prets#connect()
  endif

  if !s:is_auto_save
    call prets#request_format()
  endif
endfunction
