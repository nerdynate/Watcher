#!/usr/bin/env ruby

$outdir = 'doc/'
puts "Creating documentation in '#$outdir'."
system "rdoc -t File::Tail -m File::Tail -o #$outdir #{Dir['lib/**/*.rb'] * ' '}"
  # vim: set et sw=2 ts=2:
