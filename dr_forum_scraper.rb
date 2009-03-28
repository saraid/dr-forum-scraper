require 'net/http'
require 'parsedate'
require 'rss'

forum = "20"
category = "13"
topic = "5"
xml_file = "forum_feed.rss"

resource = Net::HTTP.new("www.play.net", 80)
resp1 = resource.get("/forums/messages.asp?command=sortnumdes&forum=#{forum}&category=#{category}&topic=#{topic}")
cookie = resp1['Set-Cookie'].split(";")[0]
resp2 = resource.get("/forums/" + resp1['location'], { 'Cookie' => cookie })
resp3 = resource.get("/forums/" + resp2['location'], { 'Cookie' => cookie })

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
  puts "x is done"
  post
}

content = RSS::Maker.make("2.0") do |feed|
  feed.channel.title = "Title"
  feed.channel.link = "http://www.play.net/forums/" + resp1['location']
  feed.channel.description = "Lorem ipsum says what"
  
  posts.each do |post|
    
    feed.items.new_item do |item|
      item.title = post[:title]
      item.author = post[:author]
      item.link = "http://www.play.net/forums/messages.asp?forum=20&category=#{category}&topic=#{topic}&message=#{post[:number]}"
      item.description = post[:content]
      item.date = post[:date]
    end
  end
end

File.open(xml_file, "w") do |f|
  f.write(content)
end
