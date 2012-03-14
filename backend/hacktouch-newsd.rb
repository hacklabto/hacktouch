#!/usr/bin/env ruby

require 'rubygems'
require 'rss/1.0'
require 'rss/2.0'
require 'open-uri'
require 'amqp'
require 'json'
require 'sequel'
require 'log4r'
require 'log4r/configurator'
require_relative 'lib/hacktouchbackendmq'
include Log4r

Configurator.load_xml_file(File.dirname(__FILE__)+'/log4r.xml')
@log = Logger.get('hacktouch::backend::newsd')

def feed_list
  db = Sequel.connect("sqlite://#{File.dirname(__FILE__)}/../frontend/hacktouch.sqlite3")
  stream_list = Array.new
  db[:news_feeds].order(:name).each do |stream|
    stream_list.push(stream[:url]);
  end
  
  stream_list
end

def refresh_feeds
  @log.info "Beginning refresh of news feeds."
  
  feeds = []
  feed_list.each do |source|
    content = ""
    @log.debug "Refreshing #{source}"
    open(source) do |s| content = s.read end
    feeds.push(RSS::Parser.parse(content, false))
  end
  @log.info "News feed refresh complete."
  feeds
end

feeds = refresh_feeds

AMQP.start(:host => 'localhost') do
  EM.add_periodic_timer(15*60) {
    feeds = refresh_feeds
  }
  
  amq = MQ.new
  amq.queue('hacktouch.news.request').subscribe{ |header, msg|
    msg = HacktouchBackendMessage.new(header, msg);
    case msg['command']
      when 'get' then
        randomFeed = feeds[rand(feeds.length)]
        randomItem = rand(randomFeed.items.length)
        response_msg = Hash.new
        response_msg['source'] = randomFeed.channel.title
        response_msg['source_url'] = randomFeed.channel.link
        response_msg['title'] = randomFeed.items[randomItem].title
        response_msg['url'] = randomFeed.items[randomItem].link
        response_msg['content'] = randomFeed.items[randomItem].description.split("at Slashdot.")[0]
        @log.debug "replying to #{header.properties[:reply_to]} with an article from #{msg['source']}"
        msg.respond_with_success response_msg
    end
  }
end
