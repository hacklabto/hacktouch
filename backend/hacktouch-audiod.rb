#!/usr/bin/env ruby

require 'rubygems'
require 'amqp'
require 'json'
require 'log4r'
require 'log4r/configurator'
require_relative 'lib/hacktouchbackendmq'
include Log4r

#VLC = "/Applications/VLC.app/Contents/MacOS/VLC";
VLC = "/usr/bin/vlc"
VLC_ARGS = "--intf=dummy --control=rc --rc-fake-tty";

class VLCControl
  def initialize
    begin
      # launch VLC and attach an I/O object to its remote control interface
      @vlc = IO.popen("#{VLC} #{VLC_ARGS} 2>/dev/null", "w+")
    rescue
      puts "error: #{$!}"
    end
  end
  
  def playlist_clear
    exec_cmd "clear"
  end

  def pause
    exec_cmd "pause"
  end
  
  def stop
    exec_cmd "stop"
  end
  
  def play
    exec_cmd "play"
  end
  
  def playlist_add(source)
    exec_cmd "add \"#{source}\""
  end
  
  def quit
    exec_cmd "quit"
  end
  
  def playing?
    flush_input(@vlc)
    @vlc.puts("is_playing")
    get_plain_response
  end
  
  def now_playing
    flush_input(@vlc)
    @vlc.puts("get_title")
    get_plain_response.chomp!
  end
  
  def flush_input(handle)
    # flush any input left in the buffer (non-blockingly, obviously)
    begin
      handle.read_nonblock(4096)
    rescue
    end
  end
  
  def get_plain_response
    # return a 'plain response' to a command, filtering out any status change messages.
    @vlc.readpartial(4096).each_line do |line|
      return line if line !~ /status change/;
    end
    ""
  end
  
  def get_retval
    re_retval     = /^\S+: returned (\d+)/;
    # capture any VLC output, then pick out the return value of the last command and discard anything else
    vlc_output = @vlc.readpartial(4096);
    re_match = re_retval.match(vlc_output);
    if(re_match) then
      return re_match[1];
    end
  end
  
  def exec_cmd(cmd)
    @vlc.puts(cmd)
    get_retval
  end
end

Configurator.load_xml_file(File.dirname(__FILE__)+'/log4r.xml')
log = Logger.get('hacktouch::backend::audiod')

AMQP.start(:host => 'localhost') do
  #AMQP.logging = true
  amq = MQ.new
  log.debug "Launching and connecting to VLC."
  vlc = VLCControl.new
  log.debug "VLC ready, subscribing to queue."
  amq.queue('hacktouch.audio.request').subscribe{ |header, msg|
    msg = HacktouchBackendMessage.new(header, msg);
    log.debug "Command '#{msg['command']}' received on request queue."
    case msg['command']
      when 'queue' then
        if(msg['source']) then
          vlc.playlist_clear
          vlc.playlist_add(msg['source']);
          vlc.stop
#          msg.respond_with_success
        else
          msg.respond_with_error "No audio source provided."
          log.warn("Queue command received with no audio source")
        end        
      when 'play' then
        if(msg['source']) then
          log.info("Playing #{msg['source']}.")
          vlc.playlist_clear
          vlc.playlist_add(msg['source']);
        else
          log.debug("Playing existing playlist item.")
          vlc.play
        end
#        msg.respond_with_success
      when 'pause' then
        vlc.pause
#        msg.respond_with_success
      when 'stop' then
        vlc.stop
#        msg.respond_with_success
      when 'now_playing' then
        response_msg = Hash.new
        response_msg['now_playing'] = vlc.now_playing
#        msg.respond_with_success response_msg
      when 'status' then
        response_msg = Hash.new
        if(vlc.playing?) then
          response_msg['status'] = "playing"
        else
          response_msg['status'] = "stopped"
        end
#        msg.respond_with_success response_msg
    end
    log.debug "Command processing complete."
  }
end
