Gem::Specification.new do |s|
  s.name        = 'trello2wr'
  s.version     = '1.0.3'
  s.date        = Time.now.strftime('%F')
  s.summary     = "A&O from Trello"
  s.description = "Generates weekly work report (A&O) from Trello board"
  s.authors     = ["Vladislav Lewin"]
  s.email       = 'vlewin[at]suse.de'
  s.files       = Dir.glob("lib/*")
  s.executables << 'trello2wr'
  s.homepage    = 'https://github.com/vlewin/trello2wr'

  s.add_runtime_dependency 'ruby-trello'
end
