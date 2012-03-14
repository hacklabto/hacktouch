# Load up the libraries
require 'rubygems'
require 'bundler'
Bundler.require(:default, ENV['RACK_ENV'])

require "./frontend/hacktouch-frontend"


# Starting the Audio and News processes
['audio', 'news'].each do |mod|
  p = fork {|| require "#{File.dirname(__FILE__)}/backend/hacktouch-#{mod}d.rb" }
  Process.detach(p)
end


# Starting the Server
map "/" do
  run HacktouchFrontend
end