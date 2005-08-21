#!/usr/bin/ruby

$:.unshift '../lib'

require 'xmpp4r'
require 'xmpp4r/versionresponder'


# A Hash containing all Version Query answers with their JIDs as keys:
versions = {}

# Command line argument checking

if ARGV.size != 2
  puts("Usage: ./rosterrename.rb <jid> <password>")
  exit
end

# Building up the connection

#Jabber::DEBUG = true

jid = Jabber::JID.new(ARGV[0])

cl = Jabber::Client.new(jid, false)
cl.connect
cl.auth(ARGV[1]) or raise "Auth failed"

# I'm not sure about the portability of 'uname -sr' here ;-)
# but that's all needed to answer version queries:
Jabber::VersionResponder.new(cl, 'xmpp4r Versionbot example', 'SVN', IO.popen('uname -sr').readlines.to_s.chomp)


cl.add_iq_callback { |iq|
  # Filter for version query results
  if (iq.type == 'result') && iq.query.kind_of?(Jabber::IqQueryVersion)
    puts "Version query result from #{iq.from}"
    # Keep track of results per JID
    versions[iq.from] = iq.query
    # Print details
    puts "  Name: #{iq.query.iname.inspect}"
    puts "  Version: #{iq.query.version.inspect}"
    puts "  OS: #{iq.query.os.inspect}"
  end
}

cl.add_presence_callback { |pres|
  # Already fingerprinted?
  unless versions.has_key?(pres.from)
    # Construct a new query
    iq = Jabber::Iq.new('get', pres.from)
    # and ask for the version
    iq.query = Jabber::IqQueryVersion.new
    puts "Asking #{iq.to} for his/her/its version"
    cl.send(iq)
  end
}

# Send initial presence
cl.send(Jabber::Presence.new.set_show(:xa).set_status('I am the evil fingerprinting robot'))

# Main loop:
loop do
  cl.process
  sleep(1)
end

cl.close