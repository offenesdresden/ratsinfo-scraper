require 'time'
require 'json'
require 'erb'

class Meeting
  attr_accessor :id, :start, :end, :name, :location, :description
end

def fmt_time t
  t.strftime "%Y%m%dT%H%M%S"
end

path = ARGV[0]
meetings = []
Dir::each_child(path) do |filename|
  next unless filename =~ /\.json$/

  json = JSON::load File::open("#{path}/#{filename}")

  now = Time::new
  next unless Time::parse(json["start"]) >= now && Time::parse(json["end"] || json["start"]) >= now

  m = Meeting::new
  m.id = json["id"]
  m.start = fmt_time Time::parse(json["start"])
  m.end = fmt_time(json["end"] ? Time::parse(json["end"]) : (Time::parse(json["start"]) + 7200))
  m.name = json["name"].gsub(/[\r\n]/, " ")
  m.location = json["locality"] ? (json["locality"] || "").gsub(/[\r\n]/, " ") : nil
  m.description = json["agendaItem"] ? json["agendaItem"].collect { |a|
    title = a["name"].gsub(/[\r\n]/, " ")
    "* #{a["number"]} #{title}"
  }.join("\\n") : nil
  meetings.push m
end

meetings.sort_by! { |m| m.id }

ical = ERB::new <<~EOF
  BEGIN:VCALENDAR
  VERSION:2.0
  METHOD:PUBLISH
  X-WR-TIMEZONE;VALUE=TEXT:Europe/Berlin
  <% meetings.each do |m| %>
  BEGIN:VEVENT
  METHOD:PUBLISH
  CLASS:PUBLIC
  UID:meeting-<%= m.id %>@ratsinfo.dresden.de
  DTSTART:<%= m.start %>
  DTEND:<%= m.end %>
  SUMMARY:<%= m.name %>
  <% if m.location %>
  LOCATION:<%= m.location %>
  <% end %>
  <% if m.description %>
  DESCRIPTION:Tagesordnung:\\n<%= m.description %>
  <% end %>
  END:VEVENT
  <% end %>
  END:VCALENDAR
EOF

puts ical.result
