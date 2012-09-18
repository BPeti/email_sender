Gem::Specification.new do |s|
  s.name = 'email_sender'
  s.version = '1.0.2'
  s.date = '2012-09-19'
  s.platform = 'ruby'
  s.required_ruby_version = '>= 1.9.1'
  s.required_rubygems_version = '>= 0'
  s.require_paths = ['lib']
  s.author = 'Peter Bakonyi'
  s.email = 'bakonyi.peter@gmail.com'
  s.homepage = 'https://github.com/BPeti/email_sender'
  s.has_rdoc = true
  s.extra_rdoc_files = ['README.rdoc']
  s.files = ['LICENSE', 'VERSION', 'README.rdoc', 'lib/email_sender.rb']
  s.summary = 'Easy to use library to send email through any SMTP server.'
  s.description = 'EmailSender is a easy to use library to send email through SMTP server based on Net::SMTP library.'
  s.license = 'LGPL-3'
end
