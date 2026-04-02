" ============== Backup ==============
" Protect changes between writes. Default values of
" updatecount (200 keystrokes) and updatetime
" (4 seconds) are fine
set swapfile
set directory^=~/.vim/swap//
" protect against crash-during-write
set writebackup
" but do not persist backup after successful write
set nobackup
" keep undo/edit history recoverable after closing and re-opening
" a file, as long as the history is around
set undofile
set undodir^=~/.vim/undo//

" ============== Motion ==============
" key combos used in navigation of multiple splited panels
" split navigations
nnoremap <C-J> <C-W><C-J>
nnoremap <C-K> <C-W><C-K>
nnoremap <C-L> <C-W><C-L>
nnoremap <C-H> <C-W><C-H>
" nature split opening
set splitbelow
set splitright
" Highlight the line we are in
set cursorline
" adjust the background and foreground of cursorline so that writing becomes
" more comfortable
" http://vim.wikia.com/wiki/Highlight_current_line
hi CursorLine term=bold cterm=bold ctermbg=black guibg=black
" Highlight all the search matches
set hlsearch
hi Search guibg=Red
" highlight when we enter character
set incsearch
" search for selected text in visual mode
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>
" searching w/ smarter casing
set ignorecase
set smartcase
" Make j/k go down and up visual lines instead of real ones. This makes word
" wrapping a lot more pleasent. NOTE enable this only in Normal and Visual mode
" instead of all modes (previous behavior w/ `map`) so that command w/ counts
" e.g `d2j` (delete 2 real, instead of visual lines below) can work as expected.
nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'
vnoremap <expr> j v:count == 0 ? 'gj' : 'j'
vnoremap <expr> k v:count == 0 ? 'gk' : 'k'

set wildmenu
set wildmode=longest:full,full

" ============== Editing ==============
" the <leader> key
let mapleader=' '
" auto reload files changed outside but inside of vim
set autoread
" enable backspacing on existing text besides start of insert, so that
" deletion behavior via CTRL-W and CTRL-H is more ergonomic 
set backspace=indent,eol,start
" General indent
" show existing tab with 4 spaces width
set tabstop=4
" when indenting with '>', use 4 spaces width
set shiftwidth=4
" On pressing tab, insert 4 spaces
set expandtab
" For editing web content, shell scripts and config files
au BufNewFile,BufRead *.json,*.yml,*.yaml,*.html,*.haml,*.css,*.xml,*.sh,*.conf,*.js,*.ts
    \ setlocal tabstop=2 |
    \ setlocal softtabstop=2 |
    \ setlocal shiftwidth=2 |
" Pretty your code
syntax on
" enable relative line number so that jumping by number become eaiser
" ruler to show the line number and column in the status bar
set number relativenumber ruler
"Enable UTF-8 support
set encoding=utf-8
" Enable accessing the system's clipboard
if has('macunix')
    set clipboard=unnamed
elseif has('linux')
    set clipboard=unnamedplus
endif
" linewrap indicator
set showbreak=↪

" ============== Plugins (and their tweaks) ==============
" https://github.com/junegunn/vim-plug
" Initialize plugin system
call plug#begin('~/.vim/plugs')
" Use awesome vim color schemes
Plug 'rafi/awesome-vim-colorschemes'
" fast word quoting / wrapping
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'andymass/vim-matchup'
" ctrlp is acceptable but prefer fzf for speedy search
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
" enable better json view
Plug 'elzr/vim-json', { 'for': 'json' }
" Language Server Protocol plugins
" supported commands see https://github.com/prabirshrestha/vim-lsp#supported-commands
Plug 'prabirshrestha/vim-lsp', { 'for': ['rust', 'go', 'c', 'python'] }
Plug 'mattn/vim-lsp-settings', { 'for': ['rust', 'go', 'c', 'python'] }
" auto-completion on edit
Plug 'prabirshrestha/asyncomplete.vim', { 'for': ['rust', 'go', 'c', 'python'] }
Plug 'prabirshrestha/asyncomplete-lsp.vim', { 'for': ['rust', 'go', 'c', 'python'] }
call plug#end()

" ============== Productivity ==============
" faster save
nnoremap <Leader>w :w<CR>
" faster save and quit
nnoremap <Leader>q :wq<CR>
" faster forced quit. Watch out for your unsaved changes!
nnoremap <Leader>Q :q!<CR>
" faster clean-up of ALL content in curernt buffer
nnoremap <Leader>D :%d<CR>
" faster panel splits
nnoremap <Leader>v :vsplit<Space>
nnoremap <Leader>V :split<Space>
" faster edit
nnoremap <Leader>e :edit<Space>
" execute shell command and output the result in new scratch buffer, split in vertical
command -nargs=* Vexc vnew | 0r! <args>
nnoremap <Leader>E :Vexc<Space>
" split and edit buffer
nnoremap <Leader>b :sb<Space>
" dim all highlights
nnoremap <Leader>n :nohl<CR>
" open a vertical termianl window
command Vter vertical terminal
nnoremap <Leader>t :Vter<CR>
" open a horizontal terminal
nnoremap <Leader>T :terminal<CR>
" jsonify text
nnoremap =j :%!python3 -m json.tool<CR>
" remap ctrlp to fuzzy search w/ fzf
nnoremap <C-P> :Files<CR>
" fast code search with given pattern w/ ripgrep
nnoremap <Leader>g :Rg<CR>

" lsp mapping setups 
" https://github.com/prabirshrestha/vim-lsp#registering-servers
function! s:on_lsp_buffer_enabled() abort
    setlocal omnifunc=lsp#complete
    setlocal signcolumn=yes
    if exists('+tagfunc') | setlocal tagfunc=lsp#tagfunc | endif
    nmap <buffer> gd <plug>(lsp-definition)
    nmap <buffer> gs <plug>(lsp-document-symbol-search)
    nmap <buffer> gS <plug>(lsp-workspace-symbol-search)
    nmap <buffer> gr <plug>(lsp-references)
    nmap <buffer> gi <plug>(lsp-implementation)
    nmap <buffer> gt <plug>(lsp-type-definition)
    nmap <buffer> gf <plug>(lsp-document-diagnostics)
    nmap <buffer> [g <plug>(lsp-previous-diagnostic)
    nmap <buffer> ]g <plug>(lsp-next-diagnostic)
    nmap <buffer> K <plug>(lsp-hover)
    nnoremap <buffer> <expr><c-d> lsp#scroll(+4)
    nnoremap <buffer> <expr><c-s> lsp#scroll(-4)

    " abort formatting if not done in 1s
    let g:lsp_format_sync_timeout = 1000
    " formatting selected file types on save
    autocmd! BufWritePre *.rs,*.go,*.c,*.h,*.py call execute('LspDocumentFormatSync')
    " TODO refer to doc to add more commands
endfunction

augroup lsp_install
    au!
    " call s:on_lsp_buffer_enabled only for languages that has the server registered.
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
augroup END

" ============== Looks ==============
" for vim 8
if (has("termguicolors"))
  set termguicolors
endif
colorscheme deus
let g:deus_termcolors=256

" disable statusline as there is no much useful information
set laststatus=0
" NOTE 3rd party color themes usually overwrite status line highlighting style
" therefore we overwrite after applying color theme.
" style status line on horizontal panel split. My take is to dim it visually
" (seems vim always shows a status line for horizontal splitted panel
" except the bottom most one) and stress it when we are in the panel associated
" with the status line. See `:h StatusLineNC` to understand why we set highlighting
" groups below differently
" > When Vim knows the normal foreground, background and underline colors,
" > 'fg', 'bg' and 'ul' can be used as color names.
hi StatusLine term=bold,reverse cterm=bold,reverse ctermfg=fg ctermbg=bg guifg=fg guibg=bg
hi StatusLineNC term=bold cterm=bold ctermfg=fg ctermbg=bg guifg=fg guibg=bg
