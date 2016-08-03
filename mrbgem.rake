MRuby::Gem::Specification.new('mruby-cookiejar') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = "Stores your secrets, so you don't have to"
  spec.add_dependency 'mruby-passwdqc'
  spec.add_dependency 'mruby-lmdb'
  spec.add_dependency 'mruby-libsodium'
  spec.add_dependency 'mruby-simplemsgpack'
  spec.add_dependency 'mruby-linenoise'
  spec.add_dependency 'mruby-string-ext'
  spec.add_dependency 'mruby-sleep'
  spec.add_dependency 'mruby-getpass'

  if spec.cc.search_header_path('err.h') && spec.cc.search_header_path('sysexits.h')
    spec.cc.defines << 'MRB_COOKIEJAR_HAS_ERR_AND_SYSEXITS_H'
  end

  spec.bins = ['cookiejar']
end
