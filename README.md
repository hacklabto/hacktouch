Installation
=============

1. Install ruby (check out rbenv if you need an easy setup)
2. `gem install bundler`
3. get this repo with git
4. run `bundle install` from the repo folder


Running the Hack Touch
=======================

`./scripts/start.sh`


Visiting the Hack Touch
========================

Visit `http://localhost:3000/` in your browser.


Legacy Instructions.. in case the other instructions are borked
===============================================================
1. Install required dependencies (most available via rubygems):
 - AMQP
 - Carrot
 - Log4r
 - JSON
 - Sinatra
 - static_assets plugin for Sinatra
 - Sass
 - Haml
 - Sequel
 - Sqlite3
 - VLC
2. Customize the VLC path in hacktouch-audiod.rb to match your installation.
3. Start the backend: "./backend/hacktouch-audiod.rb && ./backend/hacktouch-newsd.rb".
4. Start the frontend: "./frontend/hacktouch-frontend.rb".
5. Visit http://localhost:4567/ in a browser.
