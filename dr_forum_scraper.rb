#
# Built by Michael Chui (devan@play.net)
# 
# This is intended to be used in tandem with a cron job.
#
require 'net/http'
require 'parsedate'
require 'rss'

# Configuration settings.
forum = "20"
category = "13"
topic = "5"
xml_file = "forum_feed.rss"

# Pull the appropriate set of posts, sorted correctly. (Date, Descending also theoretically works.)
resource = Net::HTTP.new("www.play.net", 80)
resp1 = resource.get("/forums/messages.asp?command=sortnumdes&forum=#{forum}&category=#{category}&topic=#{topic}")
cookie = resp1['Set-Cookie'].split(";")[0]
# The lovely forum software actually performs two 302 redirects. We have to follow these.
resp2 = resource.get("/forums/" + resp1['location'], { 'Cookie' => cookie })
resp3 = resource.get("/forums/" + resp2['location'], { 'Cookie' => cookie })

# Super scraper parsing action
# What this is doing is matching text strings in the given html and pulling out the relevant bits
# The result is a very clean data structure we can transform into anything we like.
#
# Please note that many of the strings are embedded inside the regular expressions.
isdst = Time.now.isdst
post_numbers = resp3.body.scan(/tmsgc#{category}t#{topic}m\d+\"/).collect { |x| /m(\d+)\"/.match(x)[1] }
posts = post_numbers.collect { |x|
  post = Hash.new
  post[:number] = x
  post[:author] = /M#{x}.+?>([A-Z0-9-]+)<\/b>/.match(resp3.body)[1]
  metadata = /mnick_c#{category}t#{topic}m#{x}.+?normS1">(.+?)<.+? on (.+?)<.+?#{x}/m.match(resp3.body)
  post[:title] = metadata[1]
  date = ParseDate::parsedate(metadata[2])
  post[:date] = Time.local(date[5], date[4], date[3], date[2], date[1], date[0], nil, nil, isdst, isdst ? "CDT" : "CST") # Ignore time zone.
  post[:content] = /tmsgc#{category}t#{topic}m#{x}\">(.+?)<!-- message formatter by simu-andy/m.match(resp3.body)[1].strip
  post
}

# This is the RSS feed builder, using prepackaged Ruby behavior.
content = RSS::Maker.make("2.0") do |feed|
  feed.channel.title = "Title"
  feed.channel.link = "http://www.play.net/forums/" + resp1['location']
  feed.channel.description = "Lorem ipsum says what"
  
  posts.each do |post|
    
    feed.items.new_item do |item|
      item.title = post[:title]
      item.author = post[:author]
      item.link = "http://www.play.net/forums/messages.asp?forum=#{forum}&category=#{category}&topic=#{topic}&message=#{post[:number]}"
      item.description = post[:content]
      item.date = post[:date]
    end
  end
end

# And this is where we write the feed to a file.
File.open(xml_file, "w") do |f|
  f.write(content)
end
