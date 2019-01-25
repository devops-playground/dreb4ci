#!/usr/bin/env ruby

require 'bundler/setup'
require 'http'

puts HTTP.get('http://checkip.dyndns.org').body
