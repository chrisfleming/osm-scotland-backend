#!/usr/bin/env ruby

  require 'geo_ruby'
  require 'OSM/StreamParser'
  require 'OSM/Database'
  require 'json'
  require 'net/http'

  class MyCallbacks < OSM::Callbacks
    attr :ndc

   @node_c = 0

   def cn()
 	@ndc += 1
   end
 
    def node(node)
       print "." if Random.rand(50000) == 2
       true
    end

    def way(way)
       print "+" if Random.rand(10000) == 2
       true
    end

    def relation(relation)
       print "%" if Random.rand(100) == 2
       true
    end

  end


  db = OSM::Database.new
  cb = MyCallbacks.new

uri = URI.parse("http://localhost:3000/statistics/new.json")

parser = OSM::StreamParser.new(:filename => 'uddingston.osm', :callbacks => cb, :db => db)
parser.parse


print "\n"

print "nodes: #{db.nodes.count}\n"
print "ways: #{db.ways.count}\n"
print "relations: #{db.relations.count}\n"


# How do we get the highways list.

length = 0
highway_l = Hash.new() 
cycleable =0
cyelway =0 

# Node processing
named_nodes =0
places_output = "" 
boundary_output  = ""
users = Hash.new
bike_shop_count = 0
named_ways = 0

counts = Hash.new() 
lengths = Hash.new()


tlist = File.open("time.txt", "w")

db.nodes.each do |n|
  named_nodes +=1 if n[1].tags.has_key? 'name'
    
  places_output = places_output + "#{n[0]}: #{n[1].tags}\n"  if n[1].tags.has_key? 'place'
  counts["Bike Shops"] =+ 1 if n[1].tags.has_key? 'bicycle'
   users[n[1].user] = 1 
 #  users.has_key? n[1].user ? users[n[1].user] = users[n[1].user] + 1 : users[n[1].user] = 1

  tlist.print "#{n[1].timestamp} #{n[1].user} #{n[1].tags}\n"
end  



db.ways.each do |w|
  begin
    l = w[1].linestring.spherical_distance
    named_ways +=1 if w[1].tags.has_key? 'name'
    length += l
    users.has_key? w[1].user ? users[w[1].user] += 1 : users[w[1].user] = 1 
    if defined? w[1].tags['highway'] and defined? l
       t = w[1].tags['highway'];
       if highway_l.has_key?(t)
          highway_l[ t ] = highway_l[ t ] + l
#         print " #{ t }: #{ highway_l[ t ] } (#{l})\n "
       else
         highway_l[ t ] = l
       end
#      print " Highway: #{w[1].tags['highway']}\n"
       if (w[1].tags['highway'] == 'footway' or w[1].tags['highway'] == 'pedestrian' or  w[1].tags['highway'] == 'path') and w[1].tags.has_key? 'bicycle'  and w[1].tags['bicycle'] != 'no'
         print "cycleable: #{w[1].tags} #{l}m\n"
	 cycleable = cycleable + l
       end 
       if w[1].tags.has_key == 'cycleway'
   	 print "cycleway: {w[1].tags} #{l}m\n"
       end 

	boundary_output += "#{w[0]}: #{w[1].tags}\n"  if w[1].tags.has_key? 'boundary'


    end
#   print " KEYS: #{w[1].tags}\n"
  rescue
#    print "  #{w} \n" 
  end
  tlist.print "#{w[1].timestamp} #{w[1].user} #{w[1].tags} \n"
end


user_object = ""
outf = File.open("users.txt", "w")
users.each do |k, v|
   outf.print "#{k} "
end
outf.close

print "#{places_output}\n\n"
print "#{boundary_output}\n\n"

puts length

counts["Users"] = users.length
print "User count: #{users.length} \n"


highway_l.keys.each do |h|
  print "      #{h}: #{highway_l[h]} \n"
  r = Hash.new()
  r["name"] = h
  r["value"] = highway_l[h]
  r["date"]  = '2012-11-24'
  r["place_id"] = 0

  response = Net::HTTP.post_form(uri, r.to_json)
end

print "cycleable: #{cycleable} \n"
print "names_nodes: #{named_nodes}\n"
print "named_ways: #{named_ways}\n"

print "bike shopes #{bike_shop_count}\n" 

File.open("scotland.json","w") do |f|
  f.write(counts.to_json)
end

