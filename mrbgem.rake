require 'mkmf'

MRuby::Gem::Specification.new('mruby-cookiemonster') do |spec|
  spec.license = 'Apache-2'
  spec.author  = 'Hendrik Beskow'
  spec.summary = "securely stores your secrets, so you don't have to"
  spec.add_dependency 'mruby-passwdqc'
  spec.add_dependency 'mruby-lmdb'
  spec.add_dependency 'mruby-libsodium'
  spec.add_dependency 'mruby-simplemsgpack'
  spec.add_dependency 'mruby-linenoise'
  spec.add_dependency 'mruby-string-ext'
  spec.add_dependency 'mruby-secure-compare'

  if have_library('c', 'err', 'err.h') && have_const('EX_OSERR', 'sysexits.h')
    spec.cc.defines << 'MRB_COOKIEMONSTER_HAS_ERR_AND_SYSEXITS_H'
  end

  spec.bins = ['cookiemonster']
end
