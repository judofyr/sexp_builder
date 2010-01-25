# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{sexp_builder}
  s.version = "0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Magnus Holm"]
  s.date = %q{2010-01-25}
  s.email = %q{judofyr@gmail.com}
  s.files = ["COPYING", "README.rdoc", "examples/andand.rb", "lib/sexp_builder.rb", "lib/sexp_builder/context.rb", "lib/sexp_builder/query_builder.rb"]
  s.homepage = %q{http://dojo.rubyforge.org/}
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Easily to match and rewrite S-expressions}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<sexp_path>, [">= 0"])
    else
      s.add_dependency(%q<sexp_path>, [">= 0"])
    end
  else
    s.add_dependency(%q<sexp_path>, [">= 0"])
  end
end

Gemify.last_specification.manifest = %q{auto} if defined?(Gemify)
