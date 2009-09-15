#!/usr/bin/env ruby
# vim: set et sw=2 ts=2:

require 'file/tail'

filename = ARGV.pop or fail "Usage: #$0 number filename"
number = (ARGV.pop || 0).to_i.abs

File::Tail::Logfile.open(filename) do |log|
  log.backward(number).tail { |line| puts line }
end
