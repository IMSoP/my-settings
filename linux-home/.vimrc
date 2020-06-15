syntax enable

" Enable mouse, and make it work under screen
set mouse=a
""set ttymouse=xterm2
" Don't auto-highlight matches from last search
set nohlsearch
" Enable modeline comments in files
set modeline
" Make searches case insensitive, as long as they're entered in lower-case
set ignorecase
set smartcase

colorscheme darkblue

" Vhosts files, including dev per-user vhost files and live per-site vhost files
autocmd BufRead,BufNewFile /home/dev/apache/conf/*.conf set filetype=apache

" <F3> comments, <F4> uncomments
vmap <F3> :s/^/# /<CR>
vmap <F4> :s/^# //<CR>

" Distinguish between cut (x) and delete (d)
noremap x d
noremap xx dd
noremap d "_d
noremap dd "_dd

" Quick switching of Paste Mode
set pastetoggle=<F2>

" XDebug trace file syntax highlighting
augroup filetypedetect
au BufNewFile,BufRead *.xt  setf xt
augroup END

" Allow editing crontabs called ".cron" or ".crontab"
autocmd BufRead,BufNewFile *.cron,*.crontab set filetype=crontab

" I don't write Modula2 code very often...
autocmd BufRead,BufNewFile *.md set filetype=markdown

"" Toggle function list
"map <F6> :TlistToggle<CR>
"map! <F6> :TlistToggle<CR>
"
"" Toggle file tree
"map <F7> :NERDTreeToggle ~/development/cwt<CR>
"map! <F7> :NERDTreeToggle ~/development/cwt<CR>
"
"map <F8> :NERDTree /home/dev/apache/conf/users<CR>
